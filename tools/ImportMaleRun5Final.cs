using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

/// Six connected components on sheet → skip top-left → mask-copy 5 frames.
public static class ImportMaleRun5Final
{
    static readonly string SheetPath =
        @"d:\runners_rush\assets\images\male_run_sheet.png";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Pad = 28;

    public static void Main()
    {
        using (var sheet = new Bitmap(SheetPath))
        using (var cleared = ClearWhiteBg(sheet))
        {
            int w = cleared.Width, h = cleared.Height;
            int stride;
            byte[] px = LockPixels(cleared, out stride);

            var comps = FindComponents(px, stride, w, h);
            Console.WriteLine("components: " + comps.Count);
            comps.Sort((a, b) =>
            {
                int rowA = a.cy < h / 2 ? 0 : 1;
                int rowB = b.cy < h / 2 ? 0 : 1;
                int c = rowA.CompareTo(rowB);
                return c != 0 ? c : a.cx.CompareTo(b.cx);
            });
            for (int i = 0; i < comps.Count; i++)
            {
                var c = comps[i];
                Console.WriteLine("comp {0}: ({1},{2})-({3},{4}) {5}x{6} n={7}",
                    i, c.minX, c.minY, c.maxX, c.maxY,
                    c.maxX - c.minX + 1, c.maxY - c.minY + 1, c.count);
            }
            if (comps.Count < 6) throw new Exception("need 6 comps");

            var keep = comps.Skip(1).Take(5).ToList();
            int maxW = 0, maxH = 0;
            foreach (var c in keep)
            {
                int cw = c.maxX - c.minX + 1 + 8;
                int ch = c.maxY - c.minY + 1 + 8;
                if (cw > maxW) maxW = cw;
                if (ch > maxH) maxH = ch;
            }
            maxW += Pad * 2;
            maxH += Pad * 2;
            Console.WriteLine("canvas {0}x{1}", maxW, maxH);

            for (int i = 0; i < keep.Count; i++)
            {
                var c = keep[i];
                int minX = Math.Max(0, c.minX - 4);
                int minY = Math.Max(0, c.minY - 4);
                int maxX = Math.Min(w - 1, c.maxX + 4);
                int maxY = Math.Min(h - 1, c.maxY + 4);
                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;

                // Copy ONLY pixels belonging to this component
                var part = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
                BitmapData dData = part.LockBits(new Rectangle(0, 0, cw, ch),
                    ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                int dStride = Math.Abs(dData.Stride);
                byte[] dPx = new byte[dStride * ch];
                foreach (int idx in c.pixels)
                {
                    int x = idx % w, y = idx / w;
                    if (x < minX || y < minY || x > maxX || y > maxY) continue;
                    int si = y * stride + x * 4;
                    int di = (y - minY) * dStride + (x - minX) * 4;
                    dPx[di] = px[si];
                    dPx[di + 1] = px[si + 1];
                    dPx[di + 2] = px[si + 2];
                    dPx[di + 3] = px[si + 3];
                }
                Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
                part.UnlockBits(dData);

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
                    g.DrawImage(part, new Rectangle(dx, dy, dw, dh));
                    string name = "male_run_" + (i + 1) + ".png";
                    canvas.Save(Path.Combine(OutDir, name), ImageFormat.Png);
                    Console.WriteLine("wrote " + name + " from " + cw + "x" + ch);
                    if (i == 0)
                        canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
                }
                part.Dispose();
            }
        }
    }

    class Comp
    {
        public int minX, minY, maxX, maxY, cx, cy, count;
        public List<int> pixels = new List<int>();
    }

    static List<Comp> FindComponents(byte[] px, int stride, int w, int h)
    {
        // Slight dilation walk so fists connected by 1px gaps join the body,
        // but stop short of merging whole neighbors (only dilate for walk,
        // components still store original opaque pixels).
        bool[] opaque = new bool[w * h];
        bool[] walk = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                bool o = px[y * stride + x * 4 + 3] >= 28;
                opaque[y * w + x] = o;
                walk[y * w + x] = o;
            }
        const int B = 1;
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (!opaque[y * w + x]) continue;
                for (int dy = -B; dy <= B; dy++)
                    for (int dx = -B; dx <= B; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        walk[ny * w + nx] = true;
                    }
            }

        bool[] seen = new bool[w * h];
        var comps = new List<Comp>();
        int[] ox = { 1, -1, 0, 0, 1, 1, -1, -1 };
        int[] oy = { 0, 0, 1, -1, 1, -1, 1, -1 };
        int minPixels = (w * h) / 80;

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = y * w + x;
                if (seen[idx] || !walk[idx]) continue;

                var pixels = new List<int>();
                int minX = x, minY = y, maxX = x, maxY = y;
                long sumX = 0, sumY = 0;
                int opaqueCount = 0;
                var q = new Queue<int>();
                q.Enqueue(idx);
                seen[idx] = true;
                while (q.Count > 0)
                {
                    int cur = q.Dequeue();
                    int cx = cur % w, cy = cur / w;
                    if (opaque[cur])
                    {
                        pixels.Add(cur);
                        opaqueCount++;
                        sumX += cx; sumY += cy;
                        if (cx < minX) minX = cx;
                        if (cy < minY) minY = cy;
                        if (cx > maxX) maxX = cx;
                        if (cy > maxY) maxY = cy;
                    }
                    for (int d = 0; d < 8; d++)
                    {
                        int nx = cx + ox[d], ny = cy + oy[d];
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int nidx = ny * w + nx;
                        if (seen[nidx] || !walk[nidx]) continue;
                        seen[nidx] = true;
                        q.Enqueue(nidx);
                    }
                }
                if (opaqueCount < minPixels) continue;
                comps.Add(new Comp
                {
                    minX = minX, minY = minY, maxX = maxX, maxY = maxY,
                    cx = (int)(sumX / Math.Max(1, opaqueCount)),
                    cy = (int)(sumY / Math.Max(1, opaqueCount)),
                    count = opaqueCount,
                    pixels = pixels
                });
            }
        }

        comps.Sort((a, b) => b.count.CompareTo(a.count));
        if (comps.Count > 6) comps = comps.Take(6).ToList();
        return comps;
    }

    static byte[] LockPixels(Bitmap bmp, out int stride)
    {
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * bmp.Height];
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
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
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
