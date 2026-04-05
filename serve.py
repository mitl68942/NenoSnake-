import http.server
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

class UTF8Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def guess_type(self, path):
        t = super().guess_type(path)
        if t and t.startswith('text/'):
            return t + '; charset=utf-8'
        return t

http.server.HTTPServer(('', 8080), UTF8Handler).serve_forever()
