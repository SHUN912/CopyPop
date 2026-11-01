import AppKit

let root = CommandLine.arguments[1]
let dark = CommandLine.arguments.contains("--dark")
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed:r,green:g,blue:b,alpha:1) }
func render(_ pixels: Int, path: String) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let context = NSGraphicsContext(bitmapImageRep:rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
    let body = NSBezierPath(roundedRect:NSRect(x:100,y:100,width:824,height:824),xRadius:184,yRadius:184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.22); shadow.shadowOffset = NSSize(width:0,height:-14); shadow.shadowBlurRadius = 24; shadow.set()
    color(0.78,0.84,0.92).setFill(); body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors:[dark ? color(0.10,0.11,0.14) : color(0.94,0.95,0.97), dark ? color(0.16,0.17,0.20) : .white, dark ? color(0.23,0.24,0.27) : .white])!.draw(in:body,angle:90)
    let rim = NSBezierPath(roundedRect:NSRect(x:103,y:103,width:818,height:818),xRadius:181,yRadius:181)
    NSColor.white.withAlphaComponent(dark ? 0.16 : 0.7).setStroke(); rim.lineWidth=3; rim.stroke()
    // Two precisely typeset keycaps remain recognizable at Finder sizes.
    func key(_ frame: NSRect, symbol: String, size: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = color(0.16,0.25,0.40).withAlphaComponent(0.28); shadow.shadowOffset=NSSize(width:0,height:-12); shadow.shadowBlurRadius=18; shadow.set()
        let side = NSBezierPath(roundedRect:frame.offsetBy(dx:0,dy:-8),xRadius:58,yRadius:58)
        (dark ? color(0.12,0.13,0.15) : color(0.74,0.76,0.79)).setFill(); side.fill()
        NSGraphicsContext.restoreGraphicsState()
        let face = NSBezierPath(roundedRect:frame,xRadius:58,yRadius:58)
        NSGradient(colors:[dark ? color(0.22,0.23,0.26) : color(0.93,0.94,0.96),dark ? color(0.34,0.35,0.39) : .white])!.draw(in:face,angle:90)
        NSColor.white.withAlphaComponent(dark ? 0.19 : 0.9).setStroke(); face.lineWidth=3; face.stroke()
        let font = NSFont.systemFont(ofSize:size,weight:.medium)
        let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:dark ? color(0.96,0.97,0.99) : color(0.16,0.18,0.22)]
        let bounds=(symbol as NSString).size(withAttributes:attrs)
        (symbol as NSString).draw(at:NSPoint(x:frame.midX-bounds.width/2,y:frame.midY-bounds.height/2+5),withAttributes:attrs)
    }
    key(NSRect(x:200,y:450,width:356,height:350),symbol:"⌘",size:242)
    key(NSRect(x:468,y:233,width:356,height:350),symbol:"C",size:242)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}
for size in [16,32,128,256,512] {
    try render(size,path:"\(root)/AppIcon.iconset/icon_\(size)x\(size).png")
    try render(size*2,path:"\(root)/AppIcon.iconset/icon_\(size)x\(size)@2x.png")
}
try render(1024,path:"\(root)/AppIcon.png")
