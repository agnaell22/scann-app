const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function createPng(width, height) {
  // Create raw RGBA buffer
  const buffer = Buffer.alloc(width * height * 4);
  const brandBg = [13, 107, 91, 255]; // #0D6B5B
  const brandFg = [255, 255, 255, 255]; // White

  // Draw rounded rectangle background and 'B' icon mark
  const radius = Math.floor(width * 0.2);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 4;
      
      // Check corner rounding
      let inCorner = false;
      let dx = 0, dy = 0;
      if (x < radius && y < radius) { dx = radius - x; dy = radius - y; inCorner = true; }
      else if (x >= width - radius && y < radius) { dx = x - (width - radius - 1); dy = radius - y; inCorner = true; }
      else if (x < radius && y >= height - radius) { dx = radius - x; dy = y - (height - radius - 1); inCorner = true; }
      else if (x >= width - radius && y >= height - radius) { dx = x - (width - radius - 1); dy = y - (height - radius - 1); inCorner = true; }

      if (inCorner && (dx * dx + dy * dy > radius * radius)) {
        buffer[idx] = 0;
        buffer[idx + 1] = 0;
        buffer[idx + 2] = 0;
        buffer[idx + 3] = 0;
        continue;
      }

      // Draw "B" shape / sheets icon
      const nx = x / width;
      const ny = y / height;
      let isFg = false;
      
      // Vertical bar of B
      if (nx >= 0.25 && nx <= 0.40 && ny >= 0.25 && ny <= 0.75) {
        isFg = true;
      }
      // Top loop of B
      else if (nx >= 0.40 && nx <= 0.68 && ny >= 0.25 && ny <= 0.48) {
        if (!(nx >= 0.40 && nx <= 0.55 && ny >= 0.33 && ny <= 0.40)) {
          isFg = true;
        }
      }
      // Bottom loop of B
      else if (nx >= 0.40 && nx <= 0.72 && ny >= 0.48 && ny <= 0.75) {
        if (!(nx >= 0.40 && nx <= 0.57 && ny >= 0.56 && ny <= 0.67)) {
          isFg = true;
        }
      }

      const color = isFg ? brandFg : brandBg;
      buffer[idx] = color[0];
      buffer[idx + 1] = color[1];
      buffer[idx + 2] = color[2];
      buffer[idx + 3] = color[3];
    }
  }

  // Pack RGBA into PNG file format
  const lines = [];
  for (let y = 0; y < height; y++) {
    lines.push(0); // Filter type 0
    lines.push(...buffer.subarray(y * width * 4, (y + 1) * width * 4));
  }
  const idatData = zlib.deflateSync(Buffer.from(lines));

  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // Bit depth
  ihdr[9] = 6; // Color type 6 = RGBA
  ihdr[10] = 0; // Compression
  ihdr[11] = 0; // Filter
  ihdr[12] = 0; // Interlace
  const ihdrChunk = createChunk('IHDR', ihdr);

  // IDAT chunk
  const idatChunk = createChunk('IDAT', idatData);

  // IEND chunk
  const iendChunk = createChunk('IEND', Buffer.alloc(0));

  return Buffer.concat([signature, ihdrChunk, idatChunk, iendChunk]);
}

function createChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  const crc = crc32(Buffer.concat([typeBuf, data]));
  crcBuf.writeUInt32BE(crc, 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let j = 0; j < 8; j++) {
      c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0);
    }
  }
  return (c ^ ~0) >>> 0;
}

[16, 32, 64, 80, 128].forEach((size) => {
  const pngBuf = createPng(size, size);
  const outPath = path.join(__dirname, `icon-${size}.png`);
  fs.writeFileSync(outPath, pngBuf);
  console.log(`Generated ${outPath} (${size}x${size})`);
});
