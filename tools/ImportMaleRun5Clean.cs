using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

/// Per-cell crop: flood-fill character only (no neighbor scraps), bridge tiny gaps.
public static class ImportMaleRun5Clean
{
    static readonly string SheetPath =
        @"d:\runners_rush\assets\images\male_run_sheet.png";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Cols = 3;
    const int Rows = 2;
    const int Pad = 28;
    const int Bridge = 1; // px dilation to reconnect fists across 1-2px gaps

    public static void Main()
    {
        using (var sheet = new Bitmap(SheetPath))
        using (var cleared = ClearWhiteBg(sheet))
        {
            int w = cleared.Width, h = cleared.Height;
            int cellW = w / Cols, cellH = h / Rows;
            int stride;
            byte[] px = LockPixels(cleared, out stride);

            // Build bridge mask: opaque or within Bridge of opaque
            bool[] opaque = new bool[w * h];
            bool[] walk = new bool[w * h];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    bool o = px[y * stride + x * 4 + 3] >= 28;
                    opaque[y * w + x] = o;
                    walk[y * w + x] = o;
                }
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    if (!opaque[y * w + x]) continue;
                    for (int dy = -Bridge; dy <= Bridge; dy++)
                        for (int dx = -Bridge; dx <= Bridge; dx++)
                        {
                            int nx = x + dx, ny = y + dy;
                            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                            walk[ny * w + nx] = true;
                        }
                }

            // All 6 cell centers for Voronoi ownership during flood.
            var seeds = new int[6, 2];
            for (int c = 0; c < 6; c++)
            {
                int col = c % Cols, row = c / Cols;
                seeds[c, 0] = col * cellW + cellW / 2;
                seeds[c, 1] = row * cellH + (int)(cellH * 0.45);
            }

            int[] keep = { 1, 2, 3, 4, 5 };
            var parts = new Bitmap[keep.Length];
            int maxW = 0, maxH = 0;

            for (int i = 0; i < keep.Length; i++)
            {
                int cell = keep[i];
                int col = cell % Cols;
                int row = cell / Cols;
                int overlapX = cellW / 2; // wide strides cross cell lines
                int overlapY = cellH / 6;
                int winX = Math.Max(0, col * cellW - overlapX);
                int winY = Math.Max(0, row * cellH - overlapY);
                int winR = Math.Min(w, (col + 1) * cellW + overlapX);
                int winB = Math.Min(h, (row + 1) * cellH + overlapY);
                int seedX = seeds[cell, 0];
                int seedY = seeds[cell, 1];

                bool[] mask;
                int minX, minY, maxX, maxY, count;
                if (!FloodMask(walk, opaque, w, h, seedX, seedY, cell, seeds,
                        winX, winY, winR, winB,
                        out mask, out minX, out minY, out maxX, out maxY, out count))
                    throw new Exception("flood failed cell " + cell);

                // Also pull any small opaque islands inside the cell that sit
                // near the main mask (disconnected fist/scarf tip).
                AttachNearbyIslands(opaque, mask, w, h,
                    winX, winY, winR, winB, 14,
                    ref minX, ref minY, ref maxX, ref maxY);

                // Safety pad on bounds for canvas only (mask already complete)
                minX = Math.Max(0, minX - 2);
                minY = Math.Max(0, minY - 2);
                maxX = Math.Min(w - 1, maxX + 2);
                maxY = Math.Min(h - 1, maxY + 2);

                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                Console.WriteLine(
                    "cell {0}: {1}px bounds {2}x{3} @({4},{5})",
                    cell, count, cw, ch, minX, minY);

                var part = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
                BitmapData dData = part.LockBits(new Rectangle(0, 0, cw, ch),
                    ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                int dStride = Math.Abs(dData.Stride);
                byte[] dPx = new byte[dStride * ch];
                for (int y = minY; y <= maxY; y++)
                {
                    for (int x = minX; x <= maxX; x++)
                    {
                        if (!mask[y * w + x] || !opaque[y * w + x]) continue;
                        int si = y * stride + x * 4;
                        int di = (y - minY) * dStride + (x - minX) * 4;
                        dPx[di] = px[si];
                        dPx[di + 1] = px[si + 1];
                        dPx[di + 2] = px[si + 2];
                        dPx[di + 3] = px[si + 3];
                    }
                }
                Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
                part.UnlockBits(dData);
                parts[i] = part;
                if (cw > maxW) maxW = cw;
                if (ch > maxH) maxH = ch;
            }

            maxW += Pad * 2;
            maxH += Pad * 2;
            Console.WriteLine("canvas {0}x{1}", maxW, maxH);

            for (int i = 0; i < parts.Length; i++)
            {
                int cw = parts[i].Width, ch = parts[i].Height;
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
                    g.DrawImage(parts[i], new Rectangle(dx, dy, dw, dh));
                    string name = "male_run_" + (i + 1) + ".png";
                    canvas.Save(Path.Combine(OutDir, name), ImageFormat.Png);
                    Console.WriteLine("wrote " + name);
                    if (i == 0)
                        canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
                }
                parts[i].Dispose();
            }
        }
    }

    static void AttachNearbyIslands(
        bool[] opaque, bool[] mask, int w, int h,
        int winX, int winY, int winR, int winB, int maxDist,
        ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        bool[] seen = new bool[w * h];
        int[] ox = { 1, -1, 0, 0, 1, 1, -1, -1 };
        int[] oy = { 0, 0, 1, -1, 1, -1, 1, -1 };

        for (int y = winY; y < winB; y++)
        {
            for (int x = winX; x < winR; x++)
            {
                int idx = y * w + x;
                if (seen[idx] || !opaque[idx] || mask[idx]) continue;

                // Collect island
                var island = new List<int>();
                var q = new Queue<int>();
                q.Enqueue(idx);
                seen[idx] = true;
                int iMinX = x, iMinY = y, iMaxX = x, iMaxY = y;
                while (q.Count > 0)
                {
                    int cur = q.Dequeue();
                    island.Add(cur);
                    int cx = cur % w, cy = cur / w;
                    if (cx < iMinX) iMinX = cx;
                    if (cy < iMinY) iMinY = cy;
                    if (cx > iMaxX) iMaxX = cx;
                    if (cy > iMaxY) iMaxY = cy;
                    for (int d = 0; d < 8; d++)
                    {
                        int nx = cx + ox[d], ny = cy + oy[d];
                        if (nx < winX || ny < winY || nx >= winR || ny >= winB) continue;
                        int nidx = ny * w + nx;
                        if (seen[nidx] || !opaque[nidx] || mask[nidx]) continue;
                        seen[nidx] = true;
                        q.Enqueue(nidx);
                    }
                }

                // Skip large islands (another character / big scrap)
                if (island.Count > 900) continue;

                // Distance from island to main mask bbox (expanded)
                bool near = false;
                foreach (int p in island)
                {
                    int px = p % w, py = p / w;
                    // chebyshev distance to mask pixels is expensive; use bbox proximity
                    int dx = 0, dy = 0;
                    if (px < minX) dx = minX - px;
                    else if (px > maxX) dx = px - maxX;
                    if (py < minY) dy = minY - py;
                    else if (py > maxY) dy = py - maxY;
                    if (dx <= maxDist && dy <= maxDist) { near = true; break; }
                }
                if (!near) continue;

                foreach (int p in island) mask[p] = true;
                if (iMinX < minX) minX = iMinX;
                if (iMinY < minY) minY = iMinY;
                if (iMaxX > maxX) maxX = iMaxX;
                if (iMaxY > maxY) maxY = iMaxY;
                Console.WriteLine("  +island {0}px", island.Count);
            }
        }
    }

    static bool FloodMask(
        bool[] walk, bool[] opaque, int w, int h,
        int seedX, int seedY, int myCell, int[,] seeds,
        int winX, int winY, int winR, int winB,
        out bool[] mask, out int minX, out int minY, out int maxX, out int maxY,
        out int count)
    {
        mask = new bool[w * h];
        minX = minY = maxX = maxY = count = 0;

        int bestX = -1, bestY = -1, bestD = int.MaxValue;
        for (int y = winY; y < winB; y++)
            for (int x = winX; x < winR; x++)
            {
                if (!opaque[y * w + x]) continue;
                if (!Owns(x, y, myCell, seeds)) continue;
                int dx = x - seedX, dy = y - seedY;
                int d = dx * dx + dy * dy;
                if (d < bestD) { bestD = d; bestX = x; bestY = y; }
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

        while (q.Count > 0)
        {
            int cur = q.Dequeue();
            int cx = cur % w, cy = cur / w;
            if (opaque[cur])
            {
                mask[cur] = true;
                count++;
                if (cx < minX) minX = cx;
                if (cy < minY) minY = cy;
                if (cx > maxX) maxX = cx;
                if (cy > maxY) maxY = cy;
            }
            for (int d = 0; d < 8; d++)
            {
                int nx = cx + ox[d], ny = cy + oy[d];
                if (nx < winX || ny < winY || nx >= winR || ny >= winB) continue;
                if (!Owns(nx, ny, myCell, seeds)) continue;
                int nidx = ny * w + nx;
                if (seen[nidx] || !walk[nidx]) continue;
                seen[nidx] = true;
                q.Enqueue(nidx);
            }
        }
        return count > 500;
    }

    /// Soft Voronoi: pixel belongs to myCell if closest seed, with 28px bias
    /// so limbs that cross the midline still count as mine.
    static bool Owns(int x, int y, int myCell, int[,] seeds)
    {
        int myDx = x - seeds[myCell, 0];
        int myDy = y - seeds[myCell, 1];
        int myD = myDx * myDx + myDy * myDy;
        const int bias = 72 * 72; // allow limbs that cross into neighbor Voronoi
        for (int c = 0; c < 6; c++)
        {
            if (c == myCell) continue;
            int dx = x - seeds[c, 0];
            int dy = y - seeds[c, 1];
            int d = dx * dx + dy * dy;
            if (d + bias < myD) return false;
        }
        return true;
    }

    static byte[] LockPixels(Bitmap bmp, out int stride)
    {
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);
        return px;
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

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }
}

