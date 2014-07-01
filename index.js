var fs = require('fs'),
    PNG = require('pngjs').PNG,
    packer = require('./GrowingPacker');


var imgArr = [
    './images/a.png','./images/b.png','./images/c.png'
];



function createPng(width, height) {
    var png = new PNG({
        width: width,
        height: height
    });
    

    /*
     * 必须把图片的所有像素都设置为 0, 否则会出现一些随机的噪点
     */
    for (var y = 0; y < png.height; y++) {
        for (var x = 0; x < png.width; x++) {
            var idx = (png.width * y + x) << 2;

            png.data[idx] = 0;
            png.data[idx+1] = 0;
            png.data[idx+2] = 0;

            png.data[idx+3] = 0;
        }
    }
    return png;
}

function positionImage(ImgArr){
    var packer = new GrowingPacker();
    ImgArr.sort(function(a,b) { return (b.h < a.h); }); // 对小图排序
    packer.fit(ImgArr);//对小图定位
    ImgArr.root = packer.root;
    png = createPng(ImgArr.root.w,ImgArr.root.h);
    for(var n = 0 ; n < ImgArr.length ; n++) {
        var block = ImgArr[n];
        if (block.fit) {
          block.img.bitblt(png,0, 0, block.w, block.h, block.fit.x, block.fit.y);//将小图填充到大图中
        }
    }
}
function mergePng(images){
    var timer = 0;
    var spriteArr = [];
    images.forEach(function(image){
        fs.createReadStream(image).pipe(new PNG()).on('parsed', function() {
            var image = {
                img: this,
                w: this.width,
                h: this.height
            };
            spriteArr.push(image);
            timer++;
            if(timer === images.length){
                positionImage(spriteArr);
                png.pack().pipe(fs.createWriteStream('./out/out.png'));            
            }
        }).on('error', function() {
            console.log('error');
        });;
    });
}




mergePng(imgArr);
