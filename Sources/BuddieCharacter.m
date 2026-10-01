#import "BuddieCharacter.h"

static NSColor *Color(NSString *hex) {
    unsigned int n=0;
    if (![hex isKindOfClass:NSString.class] || hex.length!=7 || ![hex hasPrefix:@"#"]) return nil;
    NSScanner *s=[NSScanner scannerWithString:[hex substringFromIndex:1]];
    if (![s scanHexInt:&n] || !s.isAtEnd) return nil;
    return [NSColor colorWithSRGBRed:((n>>16)&255)/255. green:((n>>8)&255)/255. blue:(n&255)/255. alpha:1];
}
static id Fail(NSError **error, NSString *message) {
    if(error) *error=[NSError errorWithDomain:@"BuddiePack" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return nil;
}
static NSImage *LoadImage(NSURL *folder, id filename, NSUInteger *budget, NSError **error) {
    if (![filename isKindOfClass:NSString.class] || ![filename length] ||
        ![[filename pathExtension].lowercaseString isEqual:@"png"] ||
        ![[filename lastPathComponent] isEqual:filename]) return Fail(error,@"Artwork must be a PNG filename inside the pack.");
    NSURL *root=folder.URLByResolvingSymlinksInPath.URLByStandardizingPath;
    NSURL *url=[[root URLByAppendingPathComponent:filename] URLByResolvingSymlinksInPath];
    if (![url.URLByDeletingLastPathComponent.path isEqual:root.path]) return Fail(error,@"Artwork cannot link outside its pack.");
    NSNumber *size=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if(!size || size.unsignedLongLongValue>16*1024*1024) return Fail(error,@"Artwork is missing or larger than 16 MB.");
    NSData *data=[NSData dataWithContentsOfURL:url];
    const unsigned char signature[]={137,80,78,71,13,10,26,10};
    if(data.length<33 || memcmp(data.bytes,signature,8)) return Fail(error,@"Artwork is not a PNG.");
    const unsigned char *b=data.bytes;
    if(memcmp(b+12,"IHDR",4)) return Fail(error,@"PNG is missing its dimensions.");
    uint32_t width=((uint32_t)b[16]<<24)|((uint32_t)b[17]<<16)|((uint32_t)b[18]<<8)|b[19];
    uint32_t height=((uint32_t)b[20]<<24)|((uint32_t)b[21]<<16)|((uint32_t)b[22]<<8)|b[23];
    if(width<16 || height<16 || width>4096 || height>4096) return Fail(error,@"PNG dimensions must be between 16 and 4096 pixels.");
    NSUInteger bytes=(NSUInteger)width*height*4*(b[24]>8 ? 2:1);
    if(budget && bytes>*budget) return Fail(error,@"A sprite pack may decode at most 64 MB of artwork.");
    NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:data];
    if(!rep || !rep.hasAlpha || rep.pixelsWide>4096 || rep.pixelsHigh>4096 || rep.pixelsWide<16 || rep.pixelsHigh<16)
        return Fail(error,@"Artwork needs an alpha channel and dimensions between 16 and 4096 pixels.");
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(rep.pixelsWide,rep.pixelsHigh)];
    [image addRepresentation:rep]; if(budget) *budget-=bytes; return image;
}

static BOOL NumberInRange(id value, double low, double high) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID() &&
        isfinite([value doubleValue]) && [value doubleValue]>=low && [value doubleValue]<=high;
}
static BOOL Pair(id pair, double low, double high) {
    return [pair isKindOfClass:NSArray.class] && [pair count]==2 && NumberInRange(pair[0],low,high) && NumberInRange(pair[1],low,high);
}
static BOOL WritePNG(NSImage *image, NSURL *url, NSError **error) {
    NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
    NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png && [png writeToURL:url options:NSDataWritingAtomic error:error];
}

@implementation BuddieSpriteClip
- (NSTimeInterval)duration { double total=0; for(NSNumber *n in self.durations) total+=n.doubleValue; return total; }
- (NSUInteger)frameIndexAtTime:(double)time loop:(BOOL)loop {
    double duration=self.duration;
    if(!isfinite(time) || time<=0 || duration<=0 || !self.frames.count) return 0;
    if(!loop && time>=duration) return self.frames.count-1;
    time=loop ? fmod(time,duration):time;
    for(NSUInteger i=0;i<self.durations.count;i++) {
        if(time<self.durations[i].doubleValue) return i;
        time-=self.durations[i].doubleValue;
    }
    return self.frames.count-1;
}
@end

@implementation BuddieCharacter
+ (instancetype)bundledDefault {
    static BuddieCharacter *preset;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *resources=NSBundle.mainBundle.resourceURL;
        for(NSString *folder in @[@"BuddieCharacters",@"Characters"]) {
            NSURL *pack=[[resources URLByAppendingPathComponent:folder] URLByAppendingPathComponent:@"pip"];
            preset=[self loadPack:pack error:nil]; if(preset) break;
        }
        if(!preset) preset=[self new];
    });
    return [preset copy];
}
- (BOOL)savePack:(NSURL *)folder error:(NSError **)error {
    NSFileManager *fm=NSFileManager.defaultManager;
    if([fm fileExistsAtPath:folder.path]) { Fail(error,@"A buddy already exists at that location. Choose a new name."); return NO; }
    NSURL *stage=[folder.URLByDeletingLastPathComponent URLByAppendingPathComponent:[@".buddie-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    if(![fm createDirectoryAtURL:stage withIntermediateDirectories:NO attributes:nil error:error]) return NO;
    BOOL success=NO;
    @try {
        NSMutableDictionary *colors=[NSMutableDictionary new];
        for(NSString *key in @[@"body",@"ink",@"accent"]) {
            NSColor *c=[[self valueForKey:[key stringByAppendingString:@"Color"]] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            colors[key]=[NSString stringWithFormat:@"#%02X%02X%02X",(int)round(c.redComponent*255),(int)round(c.greenComponent*255),(int)round(c.blueComponent*255)];
        }
        NSMutableDictionary *rig=[@{@"width":@(self.bodySize.width),@"height":@(self.bodySize.height)} mutableCopy];
        for(NSString *key in @[@"cornerRadius",@"eyeSpacing",@"eyeSize",@"faceY",@"footSpacing",@"footSize",@"stride",@"footLift"]) rig[key]=[self valueForKey:key];
        NSMutableDictionary *art=[NSMutableDictionary new];
        for(NSString *key in @[@"body",@"foot"]) {
            NSImage *image=[self valueForKey:[key stringByAppendingString:@"Image"]]; if(!image) continue;
            NSString *filename=[key stringByAppendingString:@".png"];
            if(!WritePNG(image,[stage URLByAppendingPathComponent:filename],error)) return NO;
            art[key]=filename;
        }
        NSMutableDictionary *json=[@{@"version":@(self.clips.count ? 2:1),@"id":self.identifier,@"name":self.name,@"colors":colors,@"rig":rig,@"art":art} mutableCopy];
        if(self.clips.count) {
            NSMutableDictionary *clips=[NSMutableDictionary new];
            for(NSString *name in [self.clips.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                BuddieSpriteClip *clip=self.clips[name]; NSMutableArray *frames=[NSMutableArray new];
                for(NSUInteger i=0;i<clip.frames.count;i++) {
                    NSString *filename=[NSString stringWithFormat:@"%@-%02lu.png",name,(unsigned long)i];
                    if(!WritePNG(clip.frames[i],[stage URLByAppendingPathComponent:filename],error)) return NO;
                    [frames addObject:@{@"image":filename,@"duration":clip.durations[i]}];
                }
                clips[name]=frames;
            }
            json[@"sprites"]=@{@"canvas":@[@(self.spriteCanvas.width),@(self.spriteCanvas.height)],
                @"hotspot":@[@(self.spriteHotspot.x),@(self.spriteHotspot.y)],@"height":@(self.spriteHeight),
                @"mirrorWalk":@(self.mirrorWalk),@"directionalIdle":@(self.directionalIdle),@"clips":clips};
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
        if(!data || ![data writeToURL:[stage URLByAppendingPathComponent:@"buddy.json"] options:NSDataWritingAtomic error:error]) return NO;
        if(![BuddieCharacter loadPack:stage error:error]) return NO;
        success=[fm moveItemAtURL:stage toURL:folder error:error];
        return success;
    } @finally { if(!success) [fm removeItemAtURL:stage error:nil]; }
}
- (instancetype)init {
    if((self=[super init])) {
        _identifier=@"sprout"; _name=@"Sprout";
        _bodyColor=Color(@"#C2EB89"); _inkColor=Color(@"#283C31"); _accentColor=Color(@"#F2A899");
        _bodySize=NSMakeSize(34,32); _cornerRadius=13; _eyeSpacing=13; _eyeSize=5;
        _faceY=0; _footSpacing=10; _footSize=8; _stride=28; _footLift=5;
        _clips=@{}; _spriteHeight=64;
    } return self;
}
- (id)copyWithZone:(NSZone *)zone {
    BuddieCharacter *c=[[[self class] allocWithZone:zone] init];
    for(NSString *key in @[@"identifier",@"name",@"bodyColor",@"inkColor",@"accentColor",@"bodySize",@"cornerRadius",@"eyeSpacing",@"eyeSize",@"faceY",@"footSpacing",@"footSize",@"stride",@"footLift",@"bodyImage",@"footImage",@"clips",@"spriteCanvas",@"spriteHotspot",@"spriteHeight",@"mirrorWalk",@"directionalIdle"])
        [c setValue:[self valueForKey:key] forKey:key];
    return c;
}
+ (NSArray<BuddieCharacter *> *)presets {
    BuddieCharacter *sprout=[self new];
    BuddieCharacter *mochi=[self new]; mochi.identifier=@"mochi"; mochi.name=@"Mochi";
    mochi.bodyColor=Color(@"#F4D7D5"); mochi.inkColor=Color(@"#66474F"); mochi.bodySize=NSMakeSize(38,29); mochi.cornerRadius=15; mochi.stride=23;
    BuddieCharacter *orbit=[self new]; orbit.identifier=@"orbit"; orbit.name=@"Orbit";
    orbit.bodyColor=Color(@"#C6CCF5"); orbit.inkColor=Color(@"#383F65"); orbit.accentColor=Color(@"#EBAE73"); orbit.cornerRadius=10; orbit.eyeSpacing=15; orbit.stride=32;
    return @[sprout,mochi,orbit];
}
+ (instancetype)loadPack:(NSURL *)folder error:(NSError **)error {
    NSURL *manifest=[folder URLByAppendingPathComponent:@"buddy.json"];
    NSNumber *size=nil; [manifest getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if(!size || size.unsignedLongLongValue>65536) return Fail(error,@"The pack needs a buddy.json smaller than 64 KB.");
    NSData *data=[NSData dataWithContentsOfURL:manifest options:0 error:error];
    if(!data) return nil;
    NSDictionary *json=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if(![json isKindOfClass:NSDictionary.class] || !NumberInRange(json[@"version"],1,2) || floor([json[@"version"] doubleValue])!=[json[@"version"] doubleValue]) return Fail(error,@"Unsupported buddy.json version; expected 1 or 2.");
    for(NSString *key in @[@"id",@"name"]) if(![json[key] isKindOfClass:NSString.class] || ![json[key] length] || [json[key] length]>80) return Fail(error,@"The pack needs an id and name of 1–80 characters.");
    BuddieCharacter *c=[self new]; c.identifier=json[@"id"]; c.name=json[@"name"];
    NSDictionary *colors=json[@"colors"] ?: @{};
    if(![colors isKindOfClass:NSDictionary.class]) return Fail(error,@"colors must be an object.");
    for(NSString *key in @[@"body",@"ink",@"accent"]) if(colors[key]) {
        NSColor *color=Color(colors[key]); if(!color) return Fail(error,@"Colors must use #RRGGBB.");
        [c setValue:color forKey:[key stringByAppendingString:@"Color"]];
    }
    NSDictionary *rig=json[@"rig"] ?: @{};
    if(![rig isKindOfClass:NSDictionary.class]) return Fail(error,@"rig must be an object.");
    NSDictionary *limits=@{@"width":@[@24,@42],@"height":@[@24,@40],@"cornerRadius":@[@4,@21],@"eyeSpacing":@[@8,@20],@"eyeSize":@[@3,@7],@"faceY":@[@(-7),@7],@"footSpacing":@[@6,@14],@"footSize":@[@5,@11],@"stride":@[@16,@40],@"footLift":@[@2,@8]};
    for(NSString *key in rig) {
        NSArray *limit=limits[key]; id value=rig[key];
        if(!limit || !NumberInRange(value,[limit[0] doubleValue],[limit[1] doubleValue]))
            return Fail(error,[NSString stringWithFormat:@"Invalid rig setting: %@.",key]);
        if([key isEqual:@"width"]) c.bodySize=NSMakeSize([value doubleValue],c.bodySize.height);
        else if([key isEqual:@"height"]) c.bodySize=NSMakeSize(c.bodySize.width,[value doubleValue]);
        else [c setValue:value forKey:key];
    }
    NSDictionary *art=json[@"art"] ?: @{};
    if(![art isKindOfClass:NSDictionary.class]) return Fail(error,@"art must be an object.");
    for(NSString *key in art) {
        if(![@[@"body",@"foot"] containsObject:key]) return Fail(error,@"Supported artwork slots are body and foot.");
        NSImage *image=LoadImage(folder,art[key],NULL,error); if(!image) return nil;
        [c setValue:image forKey:[key stringByAppendingString:@"Image"]];
    }
    if([json[@"version"] isEqual:@2]) {
        if(art.count) return Fail(error,@"Sprite packs contain complete poses; omit body/foot artwork.");
        NSDictionary *sprites=json[@"sprites"];
        if(![sprites isKindOfClass:NSDictionary.class] || !Pair(sprites[@"canvas"],16,1024)) return Fail(error,@"Sprite canvas must have two dimensions between 16 and 1024 pixels.");
        c.spriteCanvas=NSMakeSize([sprites[@"canvas"][0] doubleValue],[sprites[@"canvas"][1] doubleValue]);
        if(floor(c.spriteCanvas.width)!=c.spriteCanvas.width || floor(c.spriteCanvas.height)!=c.spriteCanvas.height) return Fail(error,@"Sprite canvas dimensions must be whole pixels.");
        if(!Pair(sprites[@"hotspot"],0,1024) || [sprites[@"hotspot"][0] doubleValue]>=c.spriteCanvas.width || [sprites[@"hotspot"][1] doubleValue]>=c.spriteCanvas.height) return Fail(error,@"The sprite hotspot must lie inside its canvas.");
        c.spriteHotspot=NSMakePoint([sprites[@"hotspot"][0] doubleValue],[sprites[@"hotspot"][1] doubleValue]);
        if(!NumberInRange(sprites[@"height"],32,96)) return Fail(error,@"Sprite display height must be between 32 and 96 points.");
        c.spriteHeight=[sprites[@"height"] doubleValue];
        for(NSString *flag in @[@"mirrorWalk",@"directionalIdle"]) {
            id value=sprites[flag];
            if(value && (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID())) return Fail(error,[flag stringByAppendingString:@" must be true or false."]);
            [c setValue:@([value boolValue]) forKey:flag];
        }
        NSDictionary *definitions=sprites[@"clips"];
        if(![definitions isKindOfClass:NSDictionary.class] || !definitions[@"idle"]) return Fail(error,@"Sprite packs need an idle clip.");
        NSMutableDictionary *clips=[NSMutableDictionary new], *cache=[NSMutableDictionary new];
        NSUInteger total=0,budget=64*1024*1024;
        for(NSString *name in definitions) {
            if(![@[@"idle",@"idleLeft",@"walkRight",@"walkLeft",@"press",@"release"] containsObject:name]) return Fail(error,@"Unknown sprite clip.");
            NSArray *frames=definitions[name];
            if(![frames isKindOfClass:NSArray.class] || !frames.count || frames.count>64 || total+frames.count>64) return Fail(error,@"Sprite packs support 1–64 frames in total.");
            total+=frames.count; NSMutableArray *images=[NSMutableArray new], *durations=[NSMutableArray new];
            for(id frame in frames) {
                if(![frame isKindOfClass:NSDictionary.class] || ![frame[@"image"] isKindOfClass:NSString.class] || !NumberInRange(frame[@"duration"],1./120,30)) return Fail(error,@"Each sprite frame needs a PNG filename and a duration between 1/120 and 30 seconds.");
                NSImage *image=cache[frame[@"image"]];
                if(!image) { image=LoadImage(folder,frame[@"image"],&budget,error); if(!image) return nil; cache[frame[@"image"]]=image; }
                if(!NSEqualSizes(image.size,c.spriteCanvas)) return Fail(error,@"Every frame must match the shared sprite canvas.");
                [images addObject:image]; [durations addObject:frame[@"duration"]];
            }
            BuddieSpriteClip *clip=[BuddieSpriteClip new]; clip.frames=images; clip.durations=durations; clips[name]=clip;
        }
        c.clips=clips;
    } else if(json[@"sprites"]) return Fail(error,@"Complete sprite poses require version 2.");
    return c;
}
@end
