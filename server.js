// Basit statik dosya sunucusu — sadece yerel geliştirme/deneme kolaylığı için.
// Uygulama esasen file:// altında (mega_launcher.bat ile) çalışacak şekilde
// tasarlandı; bu sunucuya günlük kullanımda ihtiyaç yok.
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = 8080;
const root = __dirname;

http.createServer((req, res) => {
    const safeUrl = decodeURIComponent(req.url.split('?')[0]);
    const filePath = path.join(root, safeUrl === '/' ? 'FaturaMegaOkuyucu.html' : safeUrl);
    
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        let contentType = 'text/html; charset=utf-8';
        if (ext === '.js') contentType = 'application/javascript';
        else if (ext === '.css') contentType = 'text/css';
        else if (ext === '.pdf') contentType = 'application/pdf';
        else if (ext === '.png') contentType = 'image/png';
        
        res.writeHead(200, { 
            'Content-Type': contentType, 
            'Access-Control-Allow-Origin': '*' 
        });
        fs.createReadStream(filePath).pipe(res);
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Not Found');
    }
}).listen(port, () => {
    console.log(`Server running at http://localhost:${port}/`);
});
