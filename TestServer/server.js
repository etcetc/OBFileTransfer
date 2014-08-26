var express = require('express'),
    app = express(),
    multer = require('multer'),
    img = require('easyimage');

var imgs = ['png', 'jpg', 'jpeg', 'gif', 'bmp']; // only make thumbnail for these

function getExtension(fn) {
    return fn.split('.').pop();
}

function fnAppend(fn, insert) {
    var arr = fn.split('.');
    var ext = arr.pop();
    insert = (insert !== undefined) ? insert : new Date().getTime();
    return arr + '.' + insert + '.' + ext;
}

app.use(multer({
    dest: './static/files/',
    rename: function (fieldname, filename) {
        return filename.replace(/\W+/g, '-').toLowerCase();
    }
}));
app.use(express.static(__dirname + '/static'));

app.post('/upload', function (req, res) {
    console.log("Req params = %j",req.params);
    if ( req.files && req.files.file)
        console.log("Uploaded file %s",req.files.file.name);
    //  NO need to create thumb files
    if (false && imgs.indexOf(getExtension(req.files.file.name)) != -1)
        img.info(req.files.file.path, function (err, stdout, stderr) {
            if (err) throw err;
//        console.log(stdout); // could determine if resize needed here
            img.rescrop(
                {
                    src: req.files.file.path, dst: fnAppend(req.files.file.path, 'thumb'),
                    width: 50, height: 50
                },
                function (err, image) {
                    if (err) throw err;
                    res.send({image: true, file: req.files.file.originalname, savedAs: req.files.file.name, thumb: fnAppend(req.files.file.name, 'thumb')});
                }
            );
        });
    else
        res.send({image: false, file: req.files.file.originalname, savedAs: req.files.file.name});
});

var server = app.listen(3000, function () {
    console.log('listening on port %d', server.address().port);
});