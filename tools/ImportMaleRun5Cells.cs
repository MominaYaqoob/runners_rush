using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

/// Crop 5 run frames from 3x2 sheet (skip top-left) using per-cell flood fill.
public static class ImportMaleRun5Cells
{
    static readonly string SheetPath =
        @"d:\runners_rush\assets\images\male_run_sheet.png";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Cols = 3;
    const int Rows = 2;
    const int Pad = 24;

    public static void Main()
    {
        using (var sheet = new Bitmap(SheetPath))
        using (var cleared = ClearWhiteBg(sheet))
        {
            int cellW = sheet.Width / Cols;
            int cellH = sheet.Height / Rows;
            Console.WriteLine("sheet {0}x{1} cell {2}x{3}", sheet.Width, sheet.Height, cellW, cellH);

            // Skip cell 0; keep 1..5
            int[] keep = { 1, 2, 3, 4, 5 };
            var crops = new Bitmap[keep.Length];
            var bounds = new int[keep.Length][];
            int maxW = 0, maxH = 0;

            for (int i = 0; i < keep.Length; i++)
            {
                int cell = keep[i];
                int col = cell % Cols;
                int row = cell / Cols;
                // Search window: full cell + generous overlap into neighbors
                int overlapX = cellW / 3;
                int overlapY = cellH / 8;
                int winX = Math.Max(0, col * cellW - overlapX);
                int winY = Math.Max(0, row * cellH - overlapY);
                int winR = Math.Min(cleared.Width, (col + 1) * cellW + overlapX);
                int winB = Math.Min(cleared.Height, (row + 1) * cellH + overlapY);

                int seedX = col * cellW + cellW / 2;
                int seedY = row * cellH + cellH / 2;

                int minX, minY, maxX, maxY;
                if (!FloodFromSeed(cleared, seedX, seedY, winX, winY, winR, winB,
                        out minX, out minY, out maxX, out maxY))
                {
                    throw new Exception("no character in cell " + cell);
                }

                // Clamp crop to this cell's expanded window so we don't pull
                // large chunks of a neighbor, but keep limbs that cross the line.
                minX = Math.Max(winX, minX - 4);
                minY = Math.Max(winY, minY - 4);
                maxX = Math.Min(winR - 1, maxX + 4);
                maxY = Math.Min(winB - 1, maxY + 4);

                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                Console.WriteLine(
                    "cell {0} crop ({1},{2})-({3},{4}) {5}x{6}",
                    cell, minX, minY, maxX, maxY, cw, ch);

                crops[i] = cleared.Clone(
                    new Rectangle(minX, minY, cw, ch),
                    PixelFormat.Format32bppArgb);
                bounds[i] = new int[] { cw, ch };
                if (cw > maxW) maxW = cw;
                if (ch > maxH) maxH = ch;
            }

            maxW += Pad * 2;
            maxH += Pad * 2;
            Console.WriteLine("canvas {0}x{1}", maxW, maxH);

            for (int i = 0; i < crops.Length; i++)
            {
                int cw = bounds[i][0], ch = bounds[i][1];
                double scale = Math.Min(
                    (maxW - Pad * 2) / (double)cw,
                    (maxH - Pad * 2) / (double)ch);
                int dw = Math.Max(1, (int)Math.Round(cw * scale));
                int dh = Math.Max(1, (int)Math.Round(ch * scale));
                int dx = (maxW - dw) / 2;
                int dy = maxH - Pad - dh;

                using (var canvas = new Bitmap(maxW, maxH, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(canvas))
                {
                    g.Clear(Color.Transparent);
                    g.InterpolationMode =
                        System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode =
                        System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    g.DrawImage(crops[i], new Rectangle(dx, dy, dw, dh));
                    string name = "male_run_" + (i + 1) + ".png";
                    canvas.Save(Path.Combine(OutDir, name), ImageFormat.Png);
                    Console.WriteLine("wrote " + name);
                    if (i == 0)
                        canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
                }
                crops[i].Dispose();
            }
        }
    }

    /// Find nearest opaque pixel to seed inside window, then flood fill that blob.
    static bool FloodFromSeed(
        Bitmap bmp, int seedX, int seedY,
        int winX, int winY, int winR, int winB,
        out int minX, out int minY, out int maxX, out int maxY)
    {
        minX = minY = maxX = maxY = 0;
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);

        Func<int, int, bool> opaque = (x, y) =>
            x >= 0 && y >= 0 && x < w && y < h && px[y * stride + x * 4 + 3] >= 24;

        // Nearest opaque to cell center within window
        int bestX = -1, bestY = -1, bestD = int.MaxValue;
        for (int y = winY; y < winB; y++)
        {
            for (int x = winX; x < winR; x++)
            {
                if (!opaque(x, y)) continue;
                int dx = x - seedX, dy = y - seedY;
                int d = dx * dx + dy * dy;
                if (d < bestD) { bestD = d; bestX = x; bestY = y; }
            }
        }
        if (bestX < 0) return false;

        bool[] seen = new bool[w * h];
        var q = new Queue<int>();
        int start = bestY * w + bestX;
        q.Enqueue(start);
        seen[start] = true;
        minX = maxX = bestX;
        minY = maxY = bestY;
        int[] ox = { 1, -1, 0, 0, 1, 1, -1, -1 };
        int[] oy = { 0, 0, 1, -1, 1, -1, 1, -1 };
        int count = 0;

        while (q.Count > 0)
        {
            int cur = q.Dequeue();
            int cx = cur % w, cy = cur / w;
            count++;
            if (cx < minX) minX = cx;
            if (cy < minY) minY = cy;
            if (cx > maxX) maxX = cx;
            if (cy > maxY) maxY = cy;
            for (int d = 0; d < 8; d++)
            {
                int nx = cx + ox[d], ny = cy + oy[d];
                // Allow flood slightly outside window so limbs aren't cut,
                // but not into far-away cells.
                if (nx < winX - 2 || ny < winY - 2 || nx >= winR + 2 || ny >= winB + 2)
                    continue;
                if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                int nidx = ny * w + nx;
                if (seen[nidx]) continue;
                seen[nidx] = true;
                if (!opaque(nx, ny)) continue;
                q.Enqueue(nidx);
            }
        }

        Console.WriteLine("  seed ({0},{1}) pixels {2}", bestX, bestY, count);
        return count > 500;
    }

    static bool IsWhiteBg(byte r, byte g, byte b)
    {
        return r >= 242 && g >= 242 && b >= 242;
    }

    static Bitmap ClearWhiteBg(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData sData = src.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dData = dst.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(sData.Stride);
        byte[] sPx = new byte[stride * h];
        byte[] dPx = new byte[stride * h];
        Marshal.Copy(sData.Scan0, sPx, 0, sPx.Length);

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                byte b = sPx[i], g = sPx[i + 1], r = sPx[i + 2], a = sPx[i + 3];
                if (IsWhiteBg(r, g, b))
                {
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
                }
                else
                {
                    int avg = (r + g + b) / 3;
                    if (avg >= 228 && Math.Abs(r - g) < 14 && Math.Abs(g - b) < 14)
                    {
                        int t = Math.Min(255, (255 - avg) * 10);
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r; dPx[i + 3] = (byte)t;
                    }
                    else
                    {
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r;
                        dPx[i + 3] = a == 0 ? (byte)255 : a;
                    }
                }
            }
        }

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }
}
