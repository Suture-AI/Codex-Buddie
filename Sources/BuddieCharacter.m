#import "BuddieCharacter.h"

static NSColor *Color(NSString *hex) {
    unsigned int n=0;
    if (![hex isKindOfClass:NSString.class] || hex.length!=7 || ![hex hasPrefix:@"#"]) return nil;
    NSScanner *s=[NSScanner scannerWithString:[hex substringFromIndex:1]];
    if (![s scanHexInt:&n] || !s.isAtEnd) return nil;
    return [NSColor colorWithSRGBRed:((n>>16)&255)/255. green:((n>>8)&255)/255. blue:(n&255)/255. alpha:1];
}
static NSString *Hex(NSColor *color) {
    NSColor *c=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return [NSString stringWithFormat:@"#%02X%02X%02X",(int)round(c.redComponent*255),(int)round(c.greenComponent*255),(int)round(c.blueComponent*255)];
}
// Decode once per appearance change, never per animation tick. Masks are raw
// channel weights: do not color-manage them or apply the artwork's alpha twice.
static NSBitmapImageRep *Bitmap(NSImage *image) {
    for(NSImageRep *rep in image.representations) if([rep isKindOfClass:NSBitmapImageRep.class]) return (NSBitmapImageRep *)rep;
    return [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
}
static void RGBToHSV(double r,double g,double b,double *h,double *s,double *v) {
    double hi=MAX(r,MAX(g,b)),lo=MIN(r,MIN(g,b)),delta=hi-lo;
    *v=hi; *s=hi>0 ? delta/hi:0; *h=0;
    if(delta>0) {
        *h=(hi==r ? (g-b)/delta : hi==g ? 2+(b-r)/delta : 4+(r-g)/delta)/6;
        if(*h<0) *h+=1;
    }
}
static void HSVToRGB(double h,double s,double v,double *rgb) {
    h-=floor(h); double k=h*6; int sector=(int)floor(k); double f=k-sector;
    double p=v*(1-s),q=v*(1-s*f),t=v*(1-s*(1-f));
    double values[6][3]={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}};
    memcpy(rgb,values[sector%6],3*sizeof(double));
}
static NSImage *Paint(NSImage *image,NSImage *mask,NSArray<NSDictionary *> *materials,NSDictionary<NSString *,NSColor *> *colors) {
    BOOL changed=NO;
    double source[3][3]={{0}},target[3][3]={{0}}; BOOL active[3]={NO};
    for(NSDictionary *m in materials) {
        NSColor *base=Color(m[@"base"]),*color=colors[m[@"id"]] ?: base;
        if([Hex(base) isEqual:Hex(color)]) continue;
        NSUInteger channel=[m[@"channel"] unsignedIntegerValue];
        base=[base colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; color=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        RGBToHSV(base.redComponent,base.greenComponent,base.blueComponent,&source[channel][0],&source[channel][1],&source[channel][2]);
        RGBToHSV(color.redComponent,color.greenComponent,color.blueComponent,&target[channel][0],&target[channel][1],&target[channel][2]);
        active[channel]=YES; changed=YES;
    }
    if(!changed || !mask) return image;
    NSBitmapImageRep *input=Bitmap(image),*weights=Bitmap(mask);
    NSInteger w=input.pixelsWide,h=input.pixelsHigh;
    NSBitmapImageRep *out=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:NSBitmapFormatAlphaNonpremultiplied bytesPerRow:w*4 bitsPerPixel:32];
    double maximum=ldexp(1,input.bitsPerSample)-1;
    BOOL alphaFirst=(input.bitmapFormat&NSBitmapFormatAlphaFirst)!=0;
    NSUInteger alphaIndex=alphaFirst ? 0:input.samplesPerPixel-1, start=alphaFirst ? 1:0;
    BOOL gray=input.samplesPerPixel==2, premultiplied=!(input.bitmapFormat&NSBitmapFormatAlphaNonpremultiplied);
    BOOL direct=input.bitsPerSample==8 && input.samplesPerPixel==4 && !input.isPlanar && input.bitmapFormat==NSBitmapFormatAlphaNonpremultiplied;
    BOOL directMask=weights.bitsPerSample==8 && weights.samplesPerPixel==4 && !weights.isPlanar && weights.bitmapFormat==NSBitmapFormatAlphaNonpremultiplied;
    unsigned char *inputBytes=input.bitmapData,*maskBytes=weights.bitmapData,*outputBytes=out.bitmapData;
    NSInteger inputRow=input.bytesPerRow,maskRow=weights.bytesPerRow,outputRow=out.bytesPerRow;
    for(NSInteger y=0;y<h;y++) for(NSInteger x=0;x<w;x++) {
        NSUInteger samples[5]={0};
        if(direct) { unsigned char *p=inputBytes+y*inputRow+x*4; for(int k=0;k<4;k++) samples[k]=p[k]; }
        else [input getPixel:samples atX:x y:y];
        double alpha=samples[alphaIndex]/maximum;
        double original[3]={samples[start]/maximum,samples[start+(gray ? 0:1)]/maximum,samples[start+(gray ? 0:2)]/maximum};
        if(premultiplied && alpha>0)
            for(int k=0;k<3;k++) original[k]=MIN(1,original[k]/alpha);
        double result[3]={original[0],original[1],original[2]};
        NSUInteger channels[4]={0};
        if(directMask) { unsigned char *p=maskBytes+y*maskRow+x*4; for(int k=0;k<3;k++) channels[k]=p[k]; }
        else [weights getPixel:channels atX:x y:y];
        double hue,sat,val; RGBToHSV(original[0],original[1],original[2],&hue,&sat,&val);
        // Normalize overlapping masks so malformed blends cannot amplify light.
        double sum=0; for(int j=0;j<3;j++) sum+=channels[j];
        double denominator=MAX(255.,sum);
        for(int j=0;j<3;j++) if(active[j] && channels[j]) {
            double rgb[3];
            double s=source[j][1]>0 ? sat*target[j][1]/source[j][1] : target[j][1];
            // Specular highlights are low-saturation pixels: retain their light
            // instead of turning a glossy orange boot into flat blue paint.
            double ratio=source[j][2]>0 ? target[j][2]/source[j][2] : target[j][2];
            double v=val*((1-sat)+sat*ratio);
            HSVToRGB(hue+target[j][0]-source[j][0],MIN(1,s),MIN(1,v),rgb);
            for(int k=0;k<3;k++) result[k]+=(rgb[k]-original[k])*channels[j]/denominator;
        }
        unsigned char *pixel=outputBytes+y*outputRow+x*4;
        for(int k=0;k<3;k++) pixel[k]=(unsigned char)lround(MAX(0,MIN(1,result[k]))*255);
        pixel[3]=(unsigned char)lround(alpha*255);
    }
    NSImage *painted=[[NSImage alloc] initWithSize:image.size];
    NSColorSpace *space=input.colorSpace.colorSpaceModel==NSColorSpaceModelRGB ? input.colorSpace:NSColorSpace.sRGBColorSpace;
    [painted addRepresentation:[out bitmapImageRepByRetaggingWithColorSpace:space]]; return painted;
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

@interface BuddieCharacter ()
@property NSMutableDictionary<NSString *,NSImage *> *paintedFrames;
@end
@implementation BuddieCharacter
- (void)setMaterialColors:(NSDictionary<NSString *,NSColor *> *)colors {
    NSMutableDictionary *canonical=[NSMutableDictionary new];
    for(NSString *key in colors) canonical[key]=Color(Hex(colors[key]));
    _materialColors=[canonical copy]; self.paintedFrames=[NSMutableDictionary new];
}
- (void)setMaterials:(NSArray<NSDictionary *> *)materials {
    _materials=[materials copy]; self.paintedFrames=[NSMutableDictionary new];
}
- (NSImage *)imageForClip:(NSString *)name frame:(NSUInteger)index {
    BuddieSpriteClip *clip=self.clips[name];
    if(index>=clip.frames.count) return nil;
    if(!self.materials.count || !clip.masks.count) return clip.frames[index];
    NSString *key=[NSString stringWithFormat:@"%@:%lu",name,(unsigned long)index];
    NSImage *image=self.paintedFrames[key];
    if(!image) { image=Paint(clip.frames[index],clip.masks[index],self.materials,self.materialColors); self.paintedFrames[key]=image; }
    return image;
}
- (void)prepareAppearance {
    for(NSString *name in self.clips) for(NSUInteger i=0;i<self.clips[name].frames.count;i++)
        @autoreleasepool { [self imageForClip:name frame:i]; }
}
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
        NSMutableDictionary *json=[@{@"version":@(self.puppetParts.count ? 3:self.clips.count ? 2:1),@"id":self.identifier,@"name":self.name,@"colors":colors,@"rig":rig,@"art":art} mutableCopy];
        if(self.clips.count) {
            NSMutableDictionary *clips=[NSMutableDictionary new];
            for(NSString *name in [self.clips.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                BuddieSpriteClip *clip=self.clips[name]; NSMutableArray *frames=[NSMutableArray new];
                for(NSUInteger i=0;i<clip.frames.count;i++) {
                    NSString *filename=[NSString stringWithFormat:@"%@-%02lu.png",name,(unsigned long)i];
                    if(!WritePNG(clip.frames[i],[stage URLByAppendingPathComponent:filename],error)) return NO;
                    NSMutableDictionary *frame=[@{@"image":filename,@"duration":clip.durations[i]} mutableCopy];
                    if(clip.masks.count) {
                        NSString *mask=[NSString stringWithFormat:@"%@-%02lu-mask.png",name,(unsigned long)i];
                        if(!WritePNG(clip.masks[i],[stage URLByAppendingPathComponent:mask],error)) return NO;
                        frame[@"mask"]=mask;
                    }
                    [frames addObject:frame];
                }
                clips[name]=frames;
            }
            NSMutableDictionary *sprites=[@{@"canvas":@[@(self.spriteCanvas.width),@(self.spriteCanvas.height)],
                @"hotspot":@[@(self.spriteHotspot.x),@(self.spriteHotspot.y)],@"height":@(self.spriteHeight),
                @"mirrorWalk":@(self.mirrorWalk),@"directionalIdle":@(self.directionalIdle),@"pixelArt":@(self.pixelArt),@"clips":clips} mutableCopy];
            if(self.materials.count) {
                NSMutableArray *materials=[NSMutableArray new];
                for(NSDictionary *m in self.materials) {
                    NSMutableDictionary *definition=[m mutableCopy];
                    definition[@"color"]=Hex(self.materialColors[m[@"id"]] ?: Color(m[@"base"]));
                    [materials addObject:definition];
                }
                sprites[@"materials"]=materials;
            }
            if(self.puppetParts.count) {
                NSMutableDictionary *parts=[NSMutableDictionary new];
                for(NSString *name in self.puppetParts) {
                    NSMutableDictionary *part=[self.puppetParts[name] mutableCopy]; part[@"frames"]=clips[name]; parts[name]=part;
                }
                [sprites removeObjectForKey:@"clips"]; sprites[@"parts"]=parts;
                sprites[@"motionScale"]=@(self.puppetMotionScale);
                NSMutableDictionary *proportions=[NSMutableDictionary new];
                for(NSString *key in BuddieCharacter.puppetProportionRanges) proportions[key]=[self valueForKey:key];
                sprites[@"proportions"]=proportions;
                json[@"puppet"]=sprites;
            } else json[@"sprites"]=sprites;
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
        _clips=@{}; _spriteHeight=64; _materials=@[]; _materialColors=@{}; _paintedFrames=[NSMutableDictionary new];
        _puppetParts=@{}; _puppetMotionScale=3; _torsoWidth=1; _torsoHeight=1; _headScale=1;
        _armLength=1; _legLength=1; _bootWidth=1; _stanceWidth=1;
    } return self;
}
- (id)copyWithZone:(NSZone *)zone {
    BuddieCharacter *c=[[[self class] allocWithZone:zone] init];
    for(NSString *key in [@[@"identifier",@"name",@"bodyColor",@"inkColor",@"accentColor",@"bodySize",@"cornerRadius",@"eyeSpacing",@"eyeSize",@"faceY",@"footSpacing",@"footSize",@"stride",@"footLift",@"bodyImage",@"footImage",@"clips",@"spriteCanvas",@"spriteHotspot",@"spriteHeight",@"mirrorWalk",@"directionalIdle",@"pixelArt",@"materials",@"materialColors",@"puppetParts",@"puppetMotionScale"] arrayByAddingObjectsFromArray:BuddieCharacter.puppetProportionRanges.allKeys])
        [c setValue:[self valueForKey:key] forKey:key];
    return c;
}
+ (NSDictionary<NSString *,NSArray<NSNumber *> *> *)puppetProportionRanges {
    return @{@"torsoWidth":@[@.85,@1.22],@"torsoHeight":@[@.85,@1.18],@"headScale":@[@.85,@1.15],
        @"armLength":@[@.7,@1.3],@"legLength":@[@.65,@1.8],@"bootWidth":@[@.8,@1.35],@"stanceWidth":@[@.8,@1.4]};
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
    if(![json isKindOfClass:NSDictionary.class] || !NumberInRange(json[@"version"],1,3) || floor([json[@"version"] doubleValue])!=[json[@"version"] doubleValue]) return Fail(error,@"Unsupported buddy.json version; expected 1, 2 or 3.");
    BOOL puppet=[json[@"version"] isEqual:@3];
    if((puppet && json[@"sprites"]) || (!puppet && json[@"puppet"])) return Fail(error,@"Use puppet only in version 3, without sprites.");
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
    NSDictionary *limits=@{@"width":@[@24,@42],@"height":@[@24,@40],@"cornerRadius":@[@4,@21],@"eyeSpacing":@[@8,@20],@"eyeSize":@[@3,@7],@"faceY":@[@(-7),@7],@"footSpacing":@[@4,@14],@"footSize":@[@5,@11],@"stride":@[@8,@40],@"footLift":@[@2,@8]};
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
    if([json[@"version"] isEqual:@2] || puppet) {
        if(art.count) return Fail(error,@"Sprite packs contain complete poses; omit body/foot artwork.");
        NSDictionary *sprites=json[puppet ? @"puppet":@"sprites"];
        if(![sprites isKindOfClass:NSDictionary.class] || !Pair(sprites[@"canvas"],16,1024)) return Fail(error,@"Sprite canvas must have two dimensions between 16 and 1024 pixels.");
        c.spriteCanvas=NSMakeSize([sprites[@"canvas"][0] doubleValue],[sprites[@"canvas"][1] doubleValue]);
        if(floor(c.spriteCanvas.width)!=c.spriteCanvas.width || floor(c.spriteCanvas.height)!=c.spriteCanvas.height) return Fail(error,@"Sprite canvas dimensions must be whole pixels.");
        if(!Pair(sprites[@"hotspot"],0,1024) || [sprites[@"hotspot"][0] doubleValue]>=c.spriteCanvas.width || [sprites[@"hotspot"][1] doubleValue]>=c.spriteCanvas.height) return Fail(error,@"The sprite hotspot must lie inside its canvas.");
        c.spriteHotspot=NSMakePoint([sprites[@"hotspot"][0] doubleValue],[sprites[@"hotspot"][1] doubleValue]);
        if(!NumberInRange(sprites[@"height"],32,96)) return Fail(error,@"Sprite display height must be between 32 and 96 points.");
        c.spriteHeight=[sprites[@"height"] doubleValue];
        for(NSString *flag in @[@"mirrorWalk",@"directionalIdle",@"pixelArt"]) {
            id value=sprites[flag];
            if(value && (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID())) return Fail(error,[flag stringByAppendingString:@" must be true or false."]);
            [c setValue:@([value boolValue]) forKey:flag];
        }
        NSArray *materials=sprites[@"materials"] ?: @[];
        if(![materials isKindOfClass:NSArray.class] || materials.count>3) return Fail(error,@"A sprite pack supports up to three materials.");
        NSMutableSet *ids=[NSMutableSet new],*channels=[NSMutableSet new]; NSMutableDictionary *materialColors=[NSMutableDictionary new];
        for(id m in materials) {
            if(![m isKindOfClass:NSDictionary.class] || ![m[@"id"] isKindOfClass:NSString.class] || ![m[@"id"] length] || [m[@"id"] length]>40 ||
               ![m[@"name"] isKindOfClass:NSString.class] || ![m[@"name"] length] || [m[@"name"] length]>40 ||
               !NumberInRange(m[@"channel"],0,2) || floor([m[@"channel"] doubleValue])!=[m[@"channel"] doubleValue] ||
               !Color(m[@"base"]) || (m[@"color"] && !Color(m[@"color"]))) return Fail(error,@"Materials need an id, name, RGB channel (0–2), base color and optional color in #RRGGBB.");
            if([ids containsObject:m[@"id"]] || [channels containsObject:m[@"channel"]]) return Fail(error,@"Material ids and channels must be unique.");
            [ids addObject:m[@"id"]]; [channels addObject:m[@"channel"]]; materialColors[m[@"id"]]=Color(m[@"color"] ?: m[@"base"]);
        }
        c.materials=materials; c.materialColors=materialColors;
        NSArray *roles=@[@"head",@"body",@"tail",@"pawNear",@"pawFar",@"legNear",@"legFar",@"bootNear",@"bootFar"];
        NSDictionary *definitions=sprites[puppet ? @"parts":@"clips"];
        if(![definitions isKindOfClass:NSDictionary.class]) return Fail(error,@"Expected a clips or parts object.");
        if(puppet) {
            NSSet *keys=[NSSet setWithArray:definitions.allKeys];
            if(sprites[@"clips"] || ![[NSSet setWithArray:roles] isSubsetOfSet:keys] || ![keys isSubsetOfSet:[NSSet setWithArray:[roles arrayByAddingObjectsFromArray:@[@"headTurn",@"headLeft",@"bodyTurn",@"bodyLeft",@"tailTurn",@"tailLeft",@"headFocus",@"headPress",@"headRelease",@"headHalf",@"headClosed"]]]]) return Fail(error,@"Articulated packs need nine body parts, with optional head/body/tail directions and expression heads.");
            if((definitions[@"bodyTurn"]!=nil)!=(definitions[@"bodyLeft"]!=nil)) return Fail(error,@"Provide bodyTurn and bodyLeft together.");
            if((definitions[@"tailTurn"]!=nil)!=(definitions[@"tailLeft"]!=nil) || (definitions[@"tailTurn"] && !definitions[@"bodyTurn"])) return Fail(error,@"Provide tailTurn and tailLeft together with bodyTurn and bodyLeft.");
            if(!NumberInRange(sprites[@"motionScale"],.25,8)) return Fail(error,@"motionScale must be between 0.25 and 8 canvas pixels per motion unit.");
            c.puppetMotionScale=[sprites[@"motionScale"] doubleValue];
            NSDictionary *proportions=sprites[@"proportions"] ?: @{};
            if(![proportions isKindOfClass:NSDictionary.class]) return Fail(error,@"proportions must be an object.");
            NSDictionary *ranges=self.puppetProportionRanges;
            for(NSString *key in proportions) {
                NSArray *range=ranges[key];
                if(!range || !NumberInRange(proportions[key],[range[0] doubleValue],[range[1] doubleValue])) return Fail(error,@"Invalid articulated proportion.");
                [c setValue:proportions[key] forKey:key];
            }
        } else if(!definitions[@"idle"] || sprites[@"parts"]) return Fail(error,@"Sprite packs need an idle clip and cannot contain articulated parts.");
        NSMutableDictionary *clips=[NSMutableDictionary new], *cache=[NSMutableDictionary new], *parts=[NSMutableDictionary new];
        NSUInteger total=0,budget=64*1024*1024,frameLimit=puppet ? 96:64;
        for(NSString *name in definitions) {
            if(!puppet && ![@[@"idle",@"idleLeft",@"walkRight",@"walkLeft",@"turn",@"press",@"release"] containsObject:name]) return Fail(error,@"Unknown sprite clip.");
            NSDictionary *part=puppet ? definitions[name]:nil;
            if(puppet) {
                if(![part isKindOfClass:NSDictionary.class] || !Pair(part[@"pivot"],0,1024) || !Pair(part[@"anchor"],0,1024) ||
                   [part[@"anchor"][0] doubleValue]>=c.spriteCanvas.width || [part[@"anchor"][1] doubleValue]>=c.spriteCanvas.height ||
                   !NumberInRange(part[@"scale"],.01,4)) return Fail(error,@"Each part needs a pivot, an anchor inside the canvas, and a scale between 0.01 and 4.");
                BOOL leg=[name hasPrefix:@"leg"];
                if(leg && (!Pair(part[@"cuff"],-1024,1024) || !NumberInRange(part[@"span"],1,1024))) return Fail(error,@"Leg parts need a cuff offset and a positive neutral span.");
                for(NSString *key in part) if(![@[@"pivot",@"anchor",@"scale",@"frames"] containsObject:key] && !(leg && [@[@"cuff",@"span"] containsObject:key])) return Fail(error,@"Unknown articulated part setting.");
                NSMutableDictionary *metadata=[part mutableCopy]; [metadata removeObjectForKey:@"frames"]; parts[name]=metadata;
            }
            NSArray *frames=puppet ? part[@"frames"]:definitions[name];
            if(![frames isKindOfClass:NSArray.class] || !frames.count || frames.count>frameLimit || total+frames.count>frameLimit) return Fail(error,[NSString stringWithFormat:@"%@ packs support 1–%lu frames in total.",puppet ? @"Articulated":@"Sprite",(unsigned long)frameLimit]);
            total+=frames.count; NSMutableArray *images=[NSMutableArray new], *durations=[NSMutableArray new],*masks=[NSMutableArray new];
            for(id frame in frames) {
                if(![frame isKindOfClass:NSDictionary.class] || ![frame[@"image"] isKindOfClass:NSString.class] || !NumberInRange(frame[@"duration"],1./120,30)) return Fail(error,@"Each sprite frame needs a PNG filename and a duration between 1/120 and 30 seconds.");
                NSImage *image=cache[frame[@"image"]];
                if(!image) { image=LoadImage(folder,frame[@"image"],&budget,error); if(!image) return nil; cache[frame[@"image"]]=image; }
                if(puppet) {
                    if(image.size.width>1024 || image.size.height>1024 || (images.count && !NSEqualSizes(image.size,((NSImage *)images[0]).size))) return Fail(error,@"Part frames must share dimensions no larger than 1024 pixels.");
                    if([part[@"pivot"][0] doubleValue]>=image.size.width || [part[@"pivot"][1] doubleValue]>=image.size.height) return Fail(error,@"Part pivots must lie inside their artwork.");
                } else if(!NSEqualSizes(image.size,c.spriteCanvas)) return Fail(error,@"Every frame must match the shared sprite canvas.");
                [images addObject:image]; [durations addObject:frame[@"duration"]];
                if(materials.count) {
                    if(![frame[@"mask"] isKindOfClass:NSString.class]) return Fail(error,@"Each frame in a customizable sprite pack needs a material mask.");
                    NSImage *mask=cache[frame[@"mask"]];
                    if(!mask) { mask=LoadImage(folder,frame[@"mask"],&budget,error); if(!mask) return nil; cache[frame[@"mask"]]=mask; }
                    if(!NSEqualSizes(mask.size,image.size)) return Fail(error,@"Material masks must match their artwork dimensions.");
                    NSBitmapImageRep *rep=(NSBitmapImageRep *)mask.representations.firstObject;
                    if(rep.bitsPerSample!=8 || rep.samplesPerPixel!=4 || rep.isPlanar || rep.bitmapFormat!=NSBitmapFormatAlphaNonpremultiplied) return Fail(error,@"Material masks must be 8-bit RGBA PNGs.");
                    for(NSInteger y=0;y<rep.pixelsHigh;y++) for(NSInteger x=0;x<rep.pixelsWide;x++) {
                        NSUInteger p[4]; [rep getPixel:p atX:x y:y];
                        if(p[3]!=255) return Fail(error,@"Material masks use opaque RGB channel weights; their alpha must be 255.");
                    }
                    [masks addObject:mask];
                } else if(frame[@"mask"]) return Fail(error,@"Define materials before adding frame masks.");
            }
            BuddieSpriteClip *clip=[BuddieSpriteClip new]; clip.frames=images; clip.durations=durations; clip.masks=masks; clips[name]=clip;
        }
        for(NSString *name in @[@"headFocus",@"headPress",@"headRelease",@"headHalf",@"headClosed"]) if(clips[name]) {
            BuddieSpriteClip *expression=clips[name],*turn=clips[@"headTurn"];
            if(!turn || !clips[@"headLeft"] || ![expression.durations isEqual:turn.durations] ||
               ![parts[name] isEqual:parts[@"headTurn"]] || !NSEqualSizes(expression.frames[0].size,turn.frames[0].size))
                return Fail(error,@"Expression heads must match headTurn geometry and directional frame timings, with headLeft provided.");
        }
        if(clips[@"tailTurn"]) {
            BuddieSpriteClip *tail=clips[@"tail"],*turn=clips[@"tailTurn"],*left=clips[@"tailLeft"];
            if(![turn.durations isEqual:((BuddieSpriteClip *)clips[@"bodyTurn"]).durations] ||
               ![parts[@"tail"] isEqual:parts[@"tailTurn"]] || ![parts[@"tail"] isEqual:parts[@"tailLeft"]] ||
               !NSEqualSizes(tail.frames[0].size,turn.frames[0].size) || !NSEqualSizes(tail.frames[0].size,left.frames[0].size))
                return Fail(error,@"Tail directions must share tail geometry and image size; tailTurn timings must match bodyTurn.");
        }
        c.clips=clips;
        c.puppetParts=parts;
    } else if(json[@"sprites"]) return Fail(error,@"Complete sprite poses require version 2.");
    return c;
}
@end
