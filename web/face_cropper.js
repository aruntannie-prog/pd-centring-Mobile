window.autoCropFaceBase64 = async function (base64Image, targetSize) {
    try {
        if (!window.faceapi.nets.tinyFaceDetector.isLoaded) {
            console.log("Loading face-api tinyFaceDetector...");
            // Using a publicly reliable mirror for model weights
            await window.faceapi.nets.tinyFaceDetector.loadFromUri('https://justadudewhohacks.github.io/face-api.js/models');
            console.log("face-api loaded.");
        }

        return new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = 'Anonymous';
            img.onload = async () => {
                try {
                    const options = new window.faceapi.TinyFaceDetectorOptions({ inputSize: 224, scoreThreshold: 0.5 });
                    const detection = await window.faceapi.detectSingleFace(img, options);

                    let cropX = 0, cropY = 0;
                    let sideLength = Math.min(img.width, img.height);

                    if (detection) {
                        const box = detection.box;
                        const centerX = box.x + (box.width / 2);
                        const centerY = box.y + (box.height / 2);
                        sideLength = Math.max(box.width, box.height) * 1.5;
                        if (sideLength > img.width) sideLength = img.width;
                        if (sideLength > img.height) sideLength = img.height;
                        cropX = centerX - (sideLength / 2);
                        cropY = centerY - (sideLength / 2);
                        if (cropX < 0) cropX = 0;
                        if (cropY < 0) cropY = 0;
                        if (cropX + sideLength > img.width) cropX = img.width - sideLength;
                        if (cropY + sideLength > img.height) cropY = img.height - sideLength;
                        console.log("Face detected! Smart cropping applied.");
                    } else {
                        console.log("No face detected by face-api. Using center crop fallback.");
                        cropX = (img.width - sideLength) / 2;
                        cropY = (img.height - sideLength) / 2;
                    }

                    const canvas = document.createElement('canvas');
                    canvas.width = targetSize;
                    canvas.height = targetSize;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, cropX, cropY, sideLength, sideLength, 0, 0, targetSize, targetSize);

                    const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
                    const base64Str = dataUrl.split(',')[1];
                    resolve(base64Str);
                } catch (err) {
                    console.error("Face API detection error", err);
                    reject(err);
                }
            };
            img.onerror = (e) => reject("Image load error for face-api");
            img.src = 'data:image/jpeg;base64,' + base64Image;
        });
    } catch (err) {
        console.error("Global AutoCrop Error:", err);
        throw err;
    }
};
