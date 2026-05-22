#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const width = 760;
const height = 420;
const scale = 3;
const scaledWidth = width * scale;
const scaledHeight = height * scale;
const rgba = Buffer.alloc(scaledWidth * scaledHeight * 4);

function setPixel(x, y, red, green, blue, alpha = 255) {
    if (x < 0 || y < 0 || x >= scaledWidth || y >= scaledHeight) {
        return;
    }

    const offset = (y * scaledWidth + x) * 4;
    const opacity = alpha / 255;
    const inverse = 1 - opacity;
    rgba[offset] = Math.round(red * opacity + rgba[offset] * inverse);
    rgba[offset + 1] = Math.round(green * opacity + rgba[offset + 1] * inverse);
    rgba[offset + 2] = Math.round(blue * opacity + rgba[offset + 2] * inverse);
    rgba[offset + 3] = 255;
}

for (let y = 0; y < scaledHeight; y += 1) {
    const glow = Math.max(0, 1 - y / (scaledHeight * 0.9));
    const red = Math.round(244 + 11 * glow);
    const green = Math.round(245 + 10 * glow);
    const blue = Math.round(249 + 6 * glow);

    for (let x = 0; x < scaledWidth; x += 1) {
        const offset = (y * scaledWidth + x) * 4;
        rgba[offset] = red;
        rgba[offset + 1] = green;
        rgba[offset + 2] = blue;
        rgba[offset + 3] = 255;
    }
}

function drawLine(x1, y1, x2, y2, radius, color) {
    x1 *= scale;
    y1 *= scale;
    x2 *= scale;
    y2 *= scale;
    radius *= scale;

    const minX = Math.floor(Math.min(x1, x2) - radius - 2);
    const maxX = Math.ceil(Math.max(x1, x2) + radius + 2);
    const minY = Math.floor(Math.min(y1, y2) - radius - 2);
    const maxY = Math.ceil(Math.max(y1, y2) + radius + 2);
    const dx = x2 - x1;
    const dy = y2 - y1;
    const lengthSquared = dx * dx + dy * dy;

    for (let y = minY; y <= maxY; y += 1) {
        for (let x = minX; x <= maxX; x += 1) {
            const t = Math.max(
                0,
                Math.min(1, ((x - x1) * dx + (y - y1) * dy) / lengthSquared)
            );
            const projectionX = x1 + t * dx;
            const projectionY = y1 + t * dy;
            const distance = Math.hypot(x - projectionX, y - projectionY);
            const edge = Math.max(0, Math.min(1, radius + 1.8 - distance));

            if (edge > 0) {
                setPixel(
                    x,
                    y,
                    color[0],
                    color[1],
                    color[2],
                    Math.round(color[3] * Math.min(1, edge))
                );
            }
        }
    }
}

function downsample() {
    const output = Buffer.alloc(width * height * 4);

    for (let y = 0; y < height; y += 1) {
        for (let x = 0; x < width; x += 1) {
            let red = 0;
            let green = 0;
            let blue = 0;
            let alpha = 0;

            for (let sampleY = 0; sampleY < scale; sampleY += 1) {
                for (let sampleX = 0; sampleX < scale; sampleX += 1) {
                    const offset = (((y * scale + sampleY) * scaledWidth) + (x * scale + sampleX)) * 4;
                    red += rgba[offset];
                    green += rgba[offset + 1];
                    blue += rgba[offset + 2];
                    alpha += rgba[offset + 3];
                }
            }

            const samples = scale * scale;
            const outputOffset = (y * width + x) * 4;
            output[outputOffset] = Math.round(red / samples);
            output[outputOffset + 1] = Math.round(green / samples);
            output[outputOffset + 2] = Math.round(blue / samples);
            output[outputOffset + 3] = Math.round(alpha / samples);
        }
    }

    return output;
}

function crc32(buffer) {
    let crc = ~0;

    for (let i = 0; i < buffer.length; i += 1) {
        crc ^= buffer[i];
        for (let bit = 0; bit < 8; bit += 1) {
            crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
        }
    }

    return (~crc) >>> 0;
}

function pngChunk(type, data) {
    const typeBuffer = Buffer.from(type);
    const length = Buffer.alloc(4);
    const crc = Buffer.alloc(4);

    length.writeUInt32BE(data.length);
    crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));

    return Buffer.concat([length, typeBuffer, data, crc]);
}

drawLine(351, 253, 393, 211, 11, [0, 0, 0, 28]);
drawLine(393, 211, 351, 169, 11, [0, 0, 0, 28]);
drawLine(350, 252, 392, 210, 8, [37, 40, 45, 255]);
drawLine(392, 210, 350, 168, 8, [37, 40, 45, 255]);

const pixels = downsample();
const raw = Buffer.alloc((width * 4 + 1) * height);

for (let y = 0; y < height; y += 1) {
    const rowStart = y * (width * 4 + 1);
    raw[rowStart] = 0;
    pixels.copy(raw, rowStart + 1, y * width * 4, (y + 1) * width * 4);
}

const header = Buffer.alloc(13);
header.writeUInt32BE(width, 0);
header.writeUInt32BE(height, 4);
header[8] = 8;
header[9] = 6;
header[10] = 0;
header[11] = 0;
header[12] = 0;

const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", header),
    pngChunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    pngChunk("IEND", Buffer.alloc(0))
]);
const outputPath = path.join(__dirname, "Assets", "dmg-background.png");

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, png);
console.log(`Generated ${outputPath}`);
