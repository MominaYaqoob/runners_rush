using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

/// Recrop male_run_5 and male_run_6 from a 3+4 sprite sheet onto the
/// existing 431x472 canvas so head/feet are not clipped.
public static class RecropMaleRun56
{
    static readonly string Source =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-6151c3bc-154d-4113-b008-0000247edcf9.jpg";
    static readonly string Images = @"d:\runners_rush\assets\images";
    const int CanvasW = 431;
    const int CanvasH = 472;
    const int Pad = 16;

    public static void Main()
    {
        if (!File.Exists(Source))
            throw new FileNotFoundException("Sprite sheet not found", Source);

        using (var src = new Bitmap(Source))
        {
            Console.WriteLine("sheet " + src.Width + "x" + src.Height);
            byte[] px;
            int stride;
            CopyPixels(src, out px, out stride);

            int rowGap = FindRowGap(px, stride, src.Width, src.Height);
            Console.WriteLine("row gap y=" + rowGap);

            List<Rectangle> top = SplitBand(px, stride, src.Width, src.Height, 0, rowGap, 3);
            List<Rectangle> bot = SplitBand(px, stride, src.Width, src.Height, rowGap, src.Height, 4);
            Console.WriteLine("top " + top.Count + " bot " + bot.Count);
            if (bot.Count != 4)
                throw new Exception("Expected 4 bottom poses, got " + bot.Count);

            // Bottom row: 4,5,6,7 — we need indices 1 and 2 (frames 5 and 6).
            int[] want = { 1, 2 };
            int[] frameNums = { 5, 6 };
            for (int k = 0; k < want.Length; k++)
            {
                Rectangle box = bot[want[k]];
                // Expand crop so head/feet aren't clipped at cell edges.
                box = InflateClamped(box, 18, 22, src.Width, src.Height);
                Console.WriteLine("frame " + frameNums[k] + " cell " + box);

                using (var cell = src.Clone(box, PixelFormat.Format32bppArgb))
                using (var punched = PunchCheckerboard(cell))
                using (var kept = KeepLargestBlob(punched))
                {
                    int minX = kept.Width, minY = kept.Height, maxX = 0, maxY = 0;
                    ScanOpaqueBounds(kept, ref minX, ref minY, ref maxX, ref maxY);
                    if (maxX < minX)
                        throw new Exception("Frame " + frameNums[k] + " empty");

                    int cw = maxX - minX + 1;
                    int ch = maxY - minY + 1;
                    Console.WriteLine("  opaque " + cw + "x" + ch);

                    // Fit into canvas with padding; feet on bottom.
                    double scale = Math.Min(
                        (CanvasW - Pad * 2) / (double)cw,
                        (CanvasH - Pad * 2) / (double)ch);
                    int dw = Math.Max(1, (int)Math.Round(cw * scale));
                    int dh = Math.Max(1, (int)Math.Round(ch * scale));
                    int dx = (CanvasW - dw) / 2;
                    int dy = CanvasH - Pad - dh;
                    if (dy < Pad) dy = Pad;

                    using (var canvas = new Bitmap(CanvasW, CanvasH, PixelFormat.Format32bppArgb))
                    using (var g = Graphics.FromImage(canvas))
                    {
                        g.Clear(Color.Transparent);
                        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        g.DrawImage(
                            kept,
                            new Rectangle(dx, dy, dw, dh),
                            new Rectangle(minX, minY, cw, ch),
                            GraphicsUnit.Pixel);
                        string name = "male_run_" + frameNums[k] + ".png";
                        string path = Path.Combine(Images, name);
                        canvas.Save(path, ImageFormat.Png);
                        Console.WriteLine("wrote " + path + " (" + dw + "x" + dh + " at " + dx + "," + dy + ")");
                    }
                }
            }
        }
    }

    static Rectangle InflateClamped(Rectangle r, int dx, int dy, int w, int h)
    {
        int x = Math.Max(0, r.X - dx);
        int y = Math.Max(0, r.Y - dy);
        int rgt = Math.Min(w, r.Right + dx);
        int bot = Math.Min(h, r.Bottom + dy);
        return Rectangle.FromLTRB(x, y, rgt, bot);
    }

    static void CopyPixels(Bitmap src, out byte[] px, out int stride)
    {
        BitmapData data = src.LockBits(
            new Rectangle(0, 0, src.Width, src.Height),
            ImageLockMode.ReadOnly,
            PixelFormat.Format32bppArgb);
        stride = Math.Abs(data.Stride);
        px = new byte[stride * src.Height];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        src.UnlockBits(data);
    }

    static bool IsFg(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        if (chroma >= 28) return true;
        if (avg < 42) return true;
        if (avg > 210 && chroma < 12) return false;
        return chroma >= 14 && avg < 170;
    }

    static bool IsChecker(byte r, byte g, byte b, byte a)
    {
        if (a < 16) return false;
        int chroma = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        int avg = (r + g + b) / 3;
        return chroma <= 14 && avg >= 88 && avg <= 175;
    }

    static int FindRowGap(byte[] px, int stride, int w, int h)
    {
        int bestY = h / 2, bestScore = int.MaxValue;
        int y0 = h / 3, y1 = (2 * h) / 3;
        for (int y = y0; y < y1; y++)
        {
            int score = 0;
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                if (IsFg(px[i + 2], px[i + 1], px[i])) score++;
            }
            if (score < bestScore)
            {
                bestScore = score;
                bestY = y;
            }
        }
        return bestY;
    }

    static List<Rectangle> SplitBand(byte[] px, int stride, int w, int h, int y0, int y1, int expect)
    {
        bool[] col = new bool[w];
        for (int x = 0; x < w; x++)
        {
            for (int y = y0; y < y1; y++)
            {
                int i = y * stride + x * 4;
                if (IsFg(px[i + 2], px[i + 1], px[i]))
                {
                    col[x] = true;
                    break;
                }
            }
        }

        var ranges = new List<int[]>();
        int cx = 0;
        while (cx < w)
        {
            while (cx < w && !col[cx]) cx++;
            if (cx >= w) break;
            int start = cx;
            while (cx < w && col[cx]) cx++;
            ranges.Add(new int[] { start, cx - 1 });
        }

        if (ranges.Count > expect)
        {
            // Merge smallest gaps until expect count.
            while (ranges.Count > expect)
            {
                int mergeAt = 0;
                int bestGap = int.MaxValue;
                for (int i = 0; i < ranges.Count - 1; i++)
                {
                    int gap = ranges[i + 1][0] - ranges[i][1];
                    if (gap < bestGap)
                    {
                        bestGap = gap;
                        mergeAt = i;
                    }
                }
                ranges[mergeAt][1] = ranges[mergeAt + 1][1];
                ranges.RemoveAt(mergeAt + 1);
            }
        }

        var boxes = new List<Rectangle>();
        foreach (var r in ranges)
        {
            int minY = y1, maxY = y0;
            for (int yy = y0; yy < y1; yy++)
            {
                for (int xx = r[0]; xx <= r[1]; xx++)
                {
                    int i = yy * stride + xx * 4;
                    if (!IsFg(px[i + 2], px[i + 1], px[i])) continue;
                    if (yy < minY) minY = yy;
                    if (yy > maxY) maxY = yy;
                }
            }
            if (maxY >= minY)
                boxes.Add(Rectangle.FromLTRB(r[0], minY, r[1] + 1, maxY + 1));
        }
        return boxes;
    }

    static Bitmap PunchCheckerboard(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData sData = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dData = dst.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
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
                if (IsChecker(r, g, b, a) || (!IsFg(r, g, b) && a > 200 && ((r + g + b) / 3) > 180))
                {
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
                }
                else
                {
                    dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r; dPx[i + 3] = a > 0 ? a : (byte)255;
                    if (!IsFg(r, g, b) && ((r + g + b) / 3) > 200)
                        dPx[i + 3] = 0;
                }
            }
        }
        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }

    static Bitmap KeepLargestBlob(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        BitmapData data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);

        bool[] seen = new bool[w * h];
        int bestCount = 0;
        List<int> best = new List<int>();
        int[] stack = new int[w * h];
        int[] ox = { 1, -1, 0, 0 };
        int[] oy = { 0, 0, 1, -1 };

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = y * w + x;
                if (seen[idx]) continue;
                if (px[y * stride + x * 4 + 3] < 16) { seen[idx] = true; continue; }

                List<int> component = new List<int>();
                int sp = 0;
                stack[sp++] = idx;
                seen[idx] = true;
                while (sp > 0)
                {
                    int cur = stack[--sp];
                    component.Add(cur);
                    int cx = cur % w, cy = cur / w;
                    for (int d = 0; d < 4; d++)
                    {
                        int nx = cx + ox[d], ny = cy + oy[d];
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int nidx = ny * w + nx;
                        if (seen[nidx]) continue;
                        if (px[ny * stride + nx * 4 + 3] < 16) { seen[nidx] = true; continue; }
                        seen[nidx] = true;
                        stack[sp++] = nidx;
                    }
                }
                if (component.Count > bestCount)
                {
                    bestCount = component.Count;
                    best = component;
                }
            }
        }

        bool[] keep = new bool[w * h];
        foreach (int i in best) keep[i] = true;
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                if (keep[y * w + x]) continue;
                int i = y * stride + x * 4;
                px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 0;
            }
        }
        Marshal.Copy(px, 0, data.Scan0, px.Length);
        src.UnlockBits(data);

        var copy = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(copy))
            g.DrawImageUnscaled(src, 0, 0);
        return copy;
    }

    static void ScanOpaqueBounds(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);
        minX = w; minY = h; maxX = -1; maxY = -1;
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                if (px[y * stride + x * 4 + 3] < 16) continue;
                if (x < minX) minX = x;
                if (y < minY) minY = y;
                if (x > maxX) maxX = x;
                if (y > maxY) maxY = y;
            }
        }
    }
}
