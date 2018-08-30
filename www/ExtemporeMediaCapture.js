var exec = require('cordova/exec');

exports.openPreview = function(success, error) {
    exec(success, error, 'ExtemporeMediaCapture', 'openPreview');
};

exports.record = function(success, error) {
    exec(success, error, 'ExtemporeMediaCapture', 'startRecording');
};

exports.stop = () => {
    return new Promise((resolve, reject) => {
        exec(
            function (success) {
                resolve(success);
            },
            function (error) {
                reject(error)
            },
            "ExtemporeMediaCapture",
            "stopRecording"
        );
    });
}