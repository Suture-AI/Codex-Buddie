#import "BuddieLibrary.h"

static NSError *LibraryError(NSString *message) {
    return [NSError errorWithDomain:@"BuddieLibrary" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
static BOOL Identifier(id value) {
    return [value isKindOfClass:NSString.class] && [value length]>0 && [value length]<=80;
}
static NSDictionary *SettingRanges(void) {
    NSMutableDictionary *ranges=[@{@"width":@[@24,@42],@"height":@[@24,@40],@"eyeSpacing":@[@8,@20],
        @"eyeSize":@[@3,@7],@"faceY":@[@(-7),@7],@"stride":@[@8,@40],@"footLift":@[@2,@8],
        @"spriteHeight":@[@32,@96]} mutableCopy];
    [ranges addEntriesFromDictionary:BuddieCharacter.puppetProportionRanges]; return ranges;
}
static NSString *Hex(NSColor *color) {
    color=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return [NSString stringWithFormat:@"#%02X%02X%02X",(int)round(color.redComponent*255),(int)round(color.greenComponent*255),(int)round(color.blueComponent*255)];
}
static NSColor *Color(id value) {
    if(![value isKindOfClass:NSString.class] || [value length]!=7 || ![value hasPrefix:@"#"] ||
       [[value substringFromIndex:1] rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location!=NSNotFound) return nil;
    unsigned int rgb=0; [[NSScanner scannerWithString:[value substringFromIndex:1]] scanHexInt:&rgb];
    return [NSColor colorWithSRGBRed:((rgb>>16)&255)/255. green:((rgb>>8)&255)/255. blue:(rgb&255)/255. alpha:1];
}

@interface BuddieLibrary ()
@property NSURL *root;
@property NSMutableArray<BuddieCharacter *> *originals;
@property NSMutableDictionary *settings;
@property NSMutableArray<NSDictionary *> *installed;
@property(readwrite) NSError *loadError;
@property BOOL readOnly;
@end

@implementation BuddieLibrary
+ (NSURL *)defaultURL {
    NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [support URLByAppendingPathComponent:@"Codex Buddie/Studio" isDirectory:YES];
}
- (instancetype)initWithURL:(NSURL *)root bundled:(NSArray<BuddieCharacter *> *)bundled {
    if(!(self=[super init])) return nil;
    _root=root; _originals=[NSMutableArray new]; _settings=[NSMutableDictionary new]; _installed=[NSMutableArray new];
    for(BuddieCharacter *character in bundled) [_originals addObject:[character copy]];
    _selectedIdentifier=@"bit";
    NSURL *file=[root URLByAppendingPathComponent:@"library.json"];
    if(![NSFileManager.defaultManager fileExistsAtPath:file.path]) return self;
    NSNumber *size=nil; [file getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    NSData *data=size && size.unsignedLongLongValue<=1024*1024 ? [NSData dataWithContentsOfURL:file]:nil;
    id json=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    BOOL valid=[json isKindOfClass:NSDictionary.class] && [json[@"version"] isEqual:@1] &&
        CFGetTypeID((__bridge CFTypeRef)json[@"version"])!=CFBooleanGetTypeID() &&
        [json[@"installed"] isKindOfClass:NSArray.class] && [json[@"installed"] count]<=256 &&
        [json[@"settings"] isKindOfClass:NSDictionary.class] && [json[@"settings"] count]<=512 &&
        Identifier(json[@"selected"]) && [json[@"reducedMotion"] isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)json[@"reducedMotion"])==CFBooleanGetTypeID();
    NSMutableSet *ids=[NSMutableSet new],*folders=[NSMutableSet new];
    if(valid) for(id entry in json[@"installed"]) {
        if(![entry isKindOfClass:NSDictionary.class] || !Identifier(entry[@"id"]) ||
           ![entry[@"folder"] isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:entry[@"folder"]] ||
           [ids containsObject:entry[@"id"]] || [folders containsObject:entry[@"folder"]]) { valid=NO; break; }
        [ids addObject:entry[@"id"]]; [folders addObject:entry[@"folder"]];
    }
    if(valid) for(id key in json[@"settings"]) {
        if(!Identifier(key) || ![json[@"settings"][key] isKindOfClass:NSDictionary.class]) { valid=NO; break; }
    }
    if(!valid) {
        _loadError=LibraryError(@"The saved collection could not be read. It has been left untouched; changes will stay in this session.");
        _readOnly=YES; return self;
    }
    _settings=[json[@"settings"] mutableCopy]; _installed=[json[@"installed"] mutableCopy];
    _selectedIdentifier=json[@"selected"]; _reducedMotion=[json[@"reducedMotion"] boolValue];
    for(NSDictionary *entry in _installed) {
        NSURL *folder=[[root URLByAppendingPathComponent:@"Packs"] URLByAppendingPathComponent:entry[@"folder"]];
        // Only packs installed beneath this library may be loaded, including after edits to the manifest.
        NSString *parent=folder.URLByResolvingSymlinksInPath.URLByDeletingLastPathComponent.path;
        NSString *expected=[root URLByAppendingPathComponent:@"Packs"].URLByResolvingSymlinksInPath.path;
        BuddieCharacter *character=[parent isEqual:expected] ? [BuddieCharacter loadPack:folder error:nil]:nil;
        if(!character || ![character.identifier isEqual:entry[@"id"]]) {
            _loadError=LibraryError(@"One saved buddy could not be opened. Its library entry has been kept so it can be restored."); continue;
        }
        NSUInteger index=[self indexForIdentifier:character.identifier];
        if(index==NSNotFound) [_originals addObject:character]; else _originals[index]=character;
    }
    return self;
}
- (NSUInteger)indexForIdentifier:(NSString *)identifier {
    return [self.originals indexOfObjectPassingTest:^BOOL(BuddieCharacter *c,NSUInteger i,BOOL *stop) { (void)i; (void)stop; return [c.identifier isEqual:identifier]; }];
}
- (NSArray<BuddieCharacter *> *)characters { return [self.originals copy]; }
- (BuddieCharacter *)characterForIdentifier:(NSString *)identifier {
    NSUInteger index=[self indexForIdentifier:identifier]; if(index==NSNotFound) return nil;
    BuddieCharacter *c=[self.originals[index] copy]; NSDictionary *settings=self.settings[identifier];
    NSDictionary *ranges=SettingRanges();
    for(NSString *key in ranges) {
        id value=settings[key]; NSArray *range=ranges[key];
        if(![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID() ||
           !isfinite([value doubleValue]) || [value doubleValue]<[range[0] doubleValue] || [value doubleValue]>[range[1] doubleValue]) continue;
        if([key isEqual:@"width"]) c.bodySize=NSMakeSize([value doubleValue],c.bodySize.height);
        else if([key isEqual:@"height"]) c.bodySize=NSMakeSize(c.bodySize.width,[value doubleValue]);
        else [c setValue:value forKey:key];
    }
    id colors=settings[@"materials"];
    if([colors isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *palette=[c.materialColors mutableCopy];
        for(NSString *key in palette.allKeys) { NSColor *color=Color(colors[key]); if(color) palette[key]=color; }
        c.materialColors=palette;
    }
    [c prepareAppearance]; return c;
}
- (void)rememberCharacter:(BuddieCharacter *)character {
    if(!character || [self indexForIdentifier:character.identifier]==NSNotFound) return;
    NSMutableDictionary *settings=[NSMutableDictionary new],*colors=[NSMutableDictionary new];
    for(NSString *key in SettingRanges()) settings[key]=[key isEqual:@"width"] ? @(character.bodySize.width):[key isEqual:@"height"] ? @(character.bodySize.height):[character valueForKey:key];
    for(NSString *key in character.materialColors) colors[key]=Hex(character.materialColors[key]);
    settings[@"materials"]=colors; self.settings[character.identifier]=settings;
}
- (void)resetIdentifier:(NSString *)identifier { [self.settings removeObjectForKey:identifier]; }
- (BOOL)save:(NSError **)error {
    if(self.readOnly) { if(error) *error=self.loadError; return NO; }
    NSDictionary *json=@{@"version":@1,@"installed":self.installed,@"settings":self.settings,
        @"selected":self.selectedIdentifier ?: @"bit",@"reducedMotion":@(self.reducedMotion)};
    NSData *data=[NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
    if(!data) return NO;
    if(data.length>1024*1024) { if(error) *error=LibraryError(@"The saved collection settings are too large."); return NO; }
    if(![NSFileManager.defaultManager createDirectoryAtURL:self.root withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    return [data writeToURL:[self.root URLByAppendingPathComponent:@"library.json"] options:NSDataWritingAtomic error:error];
}
- (BOOL)installCharacter:(BuddieCharacter *)character error:(NSError **)error {
    if(self.readOnly) { if(error) *error=self.loadError; return NO; }
    NSUInteger entryIndex=[self.installed indexOfObjectPassingTest:^BOOL(NSDictionary *entry,NSUInteger i,BOOL *stop) { (void)i; (void)stop; return [entry[@"id"] isEqual:character.identifier]; }];
    if(entryIndex==NSNotFound && self.installed.count>=256) { if(error) *error=LibraryError(@"The Studio library can hold 256 imported buddies."); return NO; }
    NSURL *packs=[self.root URLByAppendingPathComponent:@"Packs" isDirectory:YES];
    if(![NSFileManager.defaultManager createDirectoryAtURL:packs withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSString *name=NSUUID.UUID.UUIDString.lowercaseString; NSURL *folder=[packs URLByAppendingPathComponent:name isDirectory:YES];
    if(![character savePack:folder error:error]) return NO;
    NSDictionary *previous=entryIndex==NSNotFound ? nil:self.installed[entryIndex];
    NSDictionary *oldSettings=self.settings[character.identifier]; NSString *oldSelection=self.selectedIdentifier;
    NSDictionary *entry=@{@"id":character.identifier,@"folder":name};
    if(previous) self.installed[entryIndex]=entry; else [self.installed addObject:entry];
    [self resetIdentifier:character.identifier]; self.selectedIdentifier=character.identifier;
    if(![self save:error]) {
        if(previous) self.installed[entryIndex]=previous; else [self.installed removeLastObject];
        if(oldSettings) self.settings[character.identifier]=oldSettings;
        self.selectedIdentifier=oldSelection;
        [NSFileManager.defaultManager removeItemAtURL:folder error:nil]; return NO;
    }
    NSUInteger index=[self indexForIdentifier:character.identifier];
    if(index==NSNotFound) [self.originals addObject:[character copy]]; else self.originals[index]=[character copy];
    // The new manifest is durable before removing a superseded installed copy.
    if(previous) [NSFileManager.defaultManager removeItemAtURL:[packs URLByAppendingPathComponent:previous[@"folder"]] error:nil];
    return YES;
}
@end
