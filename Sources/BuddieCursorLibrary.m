#import "BuddieCursorLibrary.h"
#import "BuddieView.h"
#import <fcntl.h>
#import <unistd.h>

@interface BuddieCursorLibrary () {
    // Accessed only on _queue.
    dispatch_queue_t _queue;
    dispatch_source_t _watcher;
    NSURL *_watchedFolder;
    NSDictionary *_loadedSelection;
    BuddieCharacter *_loadedCharacter;
    NSUInteger _reloadTicket;
    BOOL _watching;
}
@property NSURL *root;
@property(copy) BuddieBundledLoader loader;
@property NSHashTable<BuddieView *> *views;
@property(readwrite) BuddieCharacter *character;
@property(readwrite) BOOL reducedMotion;
@property(readwrite) NSError *loadError;
@property BOOL started;
@property NSUInteger generation;
@end

@implementation BuddieCursorLibrary
- (instancetype)initWithURL:(NSURL *)root bundledLoader:(BuddieBundledLoader)loader {
    if((self=[super init])) {
        _root=root.URLByStandardizingPath; _loader=[loader copy]; _views=NSHashTable.weakObjectsHashTable;
        _queue=dispatch_queue_create("ai.suture.buddie.cursor-library",DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)dealloc { if(_watcher) dispatch_source_cancel(_watcher); }
- (void)start {
    NSAssert(NSThread.isMainThread,@"Cursor subscriptions must start on the main thread");
    if(self.started) return;
    self.started=YES; NSUInteger generation=++self.generation;
    dispatch_async(_queue, ^{
        self->_watching=YES; [self watchDirectoryForGeneration:generation]; [self reloadForGeneration:generation];
    });
}
- (void)stop {
    NSAssert(NSThread.isMainThread,@"Cursor subscriptions must stop on the main thread");
    self.started=NO; ++self.generation;
    dispatch_async(_queue, ^{
        self->_watching=NO; ++self->_reloadTicket;
        if(self->_watcher) dispatch_source_cancel(self->_watcher);
        self->_watcher=nil; self->_watchedFolder=nil;
    });
}
- (void)attachView:(BuddieView *)view {
    NSAssert(NSThread.isMainThread,@"Cursor views must attach on the main thread");
    [self.views addObject:view];
    if(self.character) { view.character=self.character; view.reduceMotion=self.reducedMotion; }
}
- (void)watchDirectoryForGeneration:(NSUInteger)generation {
    if(!_watching) return;
    // Watching the directory survives atomic manifest replacement. Before the
    // first Studio save, watch the nearest existing ancestor and move inward
    // when the library directory appears. Never create the user's library here.
    NSURL *folder=self.root; int descriptor=-1;
    while(folder.path.length>1) {
        descriptor=open(folder.fileSystemRepresentation,O_EVTONLY|O_CLOEXEC);
        if(descriptor>=0) break;
        folder=folder.URLByDeletingLastPathComponent;
    }
    if(descriptor<0) return;
    if(_watcher && [_watchedFolder isEqual:folder]) { close(descriptor); return; }
    if(_watcher) dispatch_source_cancel(_watcher);
    _watchedFolder=folder;
    dispatch_source_t watcher=dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,(uintptr_t)descriptor,
        DISPATCH_VNODE_WRITE|DISPATCH_VNODE_DELETE|DISPATCH_VNODE_RENAME|DISPATCH_VNODE_REVOKE,_queue);
    _watcher=watcher;
    __weak BuddieCursorLibrary *weak=self;
    __weak dispatch_source_t weakWatcher=watcher;
    dispatch_source_set_event_handler(watcher, ^{
        BuddieCursorLibrary *s=weak; if(!s || !s->_watching) return;
        dispatch_source_t source=weakWatcher;
        if(!source || s->_watcher!=source) return;
        unsigned long flags=dispatch_source_get_data(source);
        if(flags&(DISPATCH_VNODE_DELETE|DISPATCH_VNODE_RENAME|DISPATCH_VNODE_REVOKE)) {
            dispatch_source_cancel(s->_watcher); s->_watcher=nil; s->_watchedFolder=nil;
        }
        [s watchDirectoryForGeneration:generation];
        NSUInteger ticket=++s->_reloadTicket;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),s->_queue, ^{
            if(s->_watching && s->_reloadTicket==ticket) [s reloadForGeneration:generation];
        });
    });
    dispatch_source_set_cancel_handler(watcher, ^{ close(descriptor); });
    dispatch_resume(watcher);
}
- (void)reloadForGeneration:(NSUInteger)generation {
    @autoreleasepool {
        // Nested folders may be created between an ancestor event and arming
        // its replacement watcher. Re-evaluate after the debounce, so later
        // atomic saves are watched in the final Studio directory.
        [self watchDirectoryForGeneration:generation];
        NSError *error=nil;
        NSDictionary *selection=[BuddieLibrary cursorSelectionAtURL:self.root error:&error];
        BuddieCharacter *character=_loadedCharacter;
        BOOL preserve=NO;
        if(selection && ![selection isEqual:_loadedSelection]) {
            NSMutableDictionary *appearance=[selection mutableCopy],*previous=[_loadedSelection mutableCopy];
            [appearance removeObjectForKey:@"reducedMotion"]; [previous removeObjectForKey:@"reducedMotion"];
            preserve=[selection[@"id"] isEqual:_loadedSelection[@"id"]] && [selection[@"installed"] isEqual:_loadedSelection[@"installed"]];
            if(![appearance isEqual:previous])
                character=[BuddieLibrary cursorCharacterForSelection:selection atURL:self.root bundledLoader:self.loader error:&error];
            // An import or color edit may arrive while decoding. Discard an
            // obsolete result before publishing; the directory event reloads it.
            NSDictionary *latest=[BuddieLibrary cursorSelectionAtURL:self.root error:nil];
            if(![latest isEqual:selection]) return;
        }
        if(!error && selection && character) { _loadedSelection=selection; _loadedCharacter=character; }
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!self.started || self.generation!=generation) return;
            if(error) {
                if(!self.loadError) fprintf(stderr,"[Buddie] Saved selection unavailable; keeping the current character.\n");
                self.loadError=error; return;
            }
            self.loadError=nil;
            if(!selection || !character) return;
            if(self.character!=character) fprintf(stderr,"[Buddie] Saved cursor appearance prepared.\n");
            self.character=character; self.reducedMotion=[selection[@"reducedMotion"] boolValue];
            for(BuddieView *view in self.views) {
                if(view.character!=character) [view applySavedCharacter:character preservingMotion:preserve];
                view.reduceMotion=self.reducedMotion; view.needsDisplay=YES;
            }
        });
    }
}
@end

static BuddieCursorLibrary *nativeLibrary;
void BuddieStartNativeLibrary(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"ai.suture.codex-buddie.runtime"]) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nativeLibrary=[[BuddieCursorLibrary alloc] initWithURL:BuddieLibrary.defaultURL bundledLoader:^BuddieCharacter *(NSString *identifier) {
            return [BuddieCharacter bundledCharacterWithIdentifier:identifier];
        }];
        [nativeLibrary start];
    });
}
void BuddieAttachNativeLibrary(BuddieView *view) {
    BuddieStartNativeLibrary(); [nativeLibrary attachView:view];
}
