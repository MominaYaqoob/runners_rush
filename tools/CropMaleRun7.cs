using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CropMaleRun7
{
    static readonly string Source =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-1c300064-2b82-4735-8736-179939ef1b80.jpg";
    static readonly string Images = @"d:\runners_rush\assets\images";

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

            List<Rectangle> boxes = new List<Rectangle>();
            boxes.AddRange(SplitBand(px, stride, src.Width, src.Height, 0, rowGap, 3));
            boxes.AddRange(SplitBand(px, stride, src.Width, src.Height, rowGap, src.Height, 4));

            Console.WriteLine("found " + boxes.Count + " poses");
            for (int i = 0; i < boxes.Count; i++)
                Console.WriteLine("  box " + (i + 1) + " " + boxes[i]);

            if (boxes.Count != 7)
                throw new Exception("Expected 7 poses, got " + boxes.Count);

            var punched = new Bitmap[boxes.Count];
            for (int i = 0; i < boxes.Count; i++)
            {
                using (var cell = src.Clone(boxes[i], PixelFormat.Format32bppArgb))
                {
                    Bitmap clear = PunchCheckerboard(cell);
                    punched[i] = KeepLargestBlob(clear);
                    if (!object.ReferenceEquals(clear, punched[i]))
                        clear.Dispose();
                }
            }

            int maxW = 0, maxH = 0;
            var bounds = new int[punched.Length][];
            for (int i = 0; i < punched.Length; i++)
            {
                int minX = punched[i].Width, minY = punched[i].Height, maxX = 0, maxY = 0;
                ScanOpaqueBounds(punched[i], ref minX, ref minY, ref maxX, ref maxY);
                if (maxX < minX)
                    throw new Exception("Frame " + (i + 1) + " is empty after punch");
                bounds[i] = new int[] { minX, minY, maxX, maxY };
                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                Console.WriteLine("  opaque " + (i + 1) + " " + cw + "x" + ch + " at " + minX + "," + minY);
                if (cw > maxW) maxW = cw;
                if (ch > maxH) maxH = ch;
            }
            maxW += 24;
            maxH += 24;
            Console.WriteLine("unified canvas " + maxW + "x" + maxH);

            for (int i = 0; i < punched.Length; i++)
            {
                int minX = bounds[i][0], minY = bounds[i][1], maxX = bounds[i][2], maxY = bounds[i][3];
                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                using (var canvas = new Bitmap(maxW, maxH, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(canvas))
                {
                    g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                    g.Clear(Color.Transparent);
                    int dx = (maxW - cw) / 2;
                    int dy = maxH - ch;
                    g.DrawImage(
                        punched[i],
                        new Rectangle(dx, dy, cw, ch),
                        new Rectangle(minX, minY, cw, ch),
                        GraphicsUnit.Pixel);
                    string name = "male_run_" + (i + 1) + ".png";
                    canvas.Save(Path.Combine(Images, name), ImageFormat.Png);
                    Console.WriteLine("wrote " + name);
                    if (i == 0)
                    {
                        canvas.Save(Path.Combine(Images, "male_run.png"), ImageFormat.Png);
                        Console.WriteLine("wrote male_run.png");
                    }
                }
                punched[i].Dispose();
            }
        }
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
        if (avg <= 40) return true;
        return false;
    }

    static bool IsChecker(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        // Warm JPEG checker: ~RGB(77,62,55) and ~RGB(133,124,115)
        if (chroma <= 36 && avg >= 48 && avg <= 185) return true;
        if (ColorDist(r, g, b, 133, 124, 115) <= 30) return true;
        if (ColorDist(r, g, b, 77, 62, 55) <= 30) return true;
        return false;
    }

    static int ColorDist(int r, int g, int b, int r2, int g2, int b2)
    {
        int dr = r - r2, dg = g - g2, db = b - b2;
        return (int)Math.Sqrt(dr * dr + dg * dg + db * db);
    }

    static int FindRowGap(byte[] px, int stride, int w, int h)
    {
        int[] rows = new int[h];
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            int n = 0;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                if (IsFg(px[i + 2], px[i + 1], px[i])) n++;
            }
            rows[y] = n;
        }

        int bestY = h / 2;
        int bestV = int.MaxValue;
        int y0 = h / 3;
        int y1 = (h * 2) / 3;
        for (int y = y0; y < y1; y++)
        {
            int v = 0;
            for (int k = -6; k <= 6; k++)
                v += rows[y + k];
            if (v < bestV)
            {
                bestV = v;
                bestY = y;
            }
        }
        return bestY;
    }

    static List<Rectangle> SplitBand(byte[] px, int stride, int w, int h, int y0, int y1, int expected)
    {
        int[] cols = new int[w];
        for (int y = y0; y < y1; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                if (IsFg(px[i + 2], px[i + 1], px[i]))
                    cols[x]++;
            }
        }

        int[] smooth = new int[w];
        for (int x = 8; x < w - 8; x++)
        {
            int n = 0;
            for (int k = -8; k <= 8; k++) n += cols[x + k];
            smooth[x] = n;
        }

        int[] peaks = FindPeaks(smooth, expected, 120);
        if (peaks.Length != expected)
            throw new Exception("Band y=" + y0 + " expected " + expected + " peaks, got " + peaks.Length);

        int[] cuts = new int[expected + 1];
        cuts[0] = Math.Max(0, FirstNonZero(smooth) - 12);
        cuts[expected] = Math.Min(w, LastNonZero(smooth) + 13);
        for (int i = 0; i < expected - 1; i++)
        {
            int a = peaks[i];
            int b = peaks[i + 1];
            int bestX = (a + b) / 2;
            int bestV = int.MaxValue;
            for (int x = a + 20; x < b - 20; x++)
            {
                if (smooth[x] < bestV)
                {
                    bestV = smooth[x];
                    bestX = x;
                }
            }
            cuts[i + 1] = bestX;
        }

        // Bottom row poses sit closer together. Frame 4's leading foot was
        // getting clipped by the old left-shift of cuts[1].
        if (expected == 4)
        {
            cuts[0] = 0;
            cuts[expected] = w;
            cuts[1] += 36;
            cuts[3] -= 70;
        }

        var rects = new List<Rectangle>();
        for (int i = 0; i < expected; i++)
        {
            int x0 = Math.Max(0, cuts[i]);
            int x1 = Math.Min(w, cuts[i + 1]);

            int minX = x1, maxX = x0;
            for (int y = y0; y < y1; y++)
            {
                int row = y * stride;
                for (int x = x0; x < x1; x++)
                {
                    int pi = row + x * 4;
                    if (!IsFg(px[pi + 2], px[pi + 1], px[pi])) continue;
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                }
            }
            if (maxX < minX)
                throw new Exception("Empty cell " + i + " in band y=" + y0);

            int padX = 12;
            int rx = Math.Max(x0, minX - padX);
            // Keep the full band vertically so hair and boots are not trimmed.
            int ry = Math.Max(0, y0 - (expected == 4 ? 12 : 8));
            int rRight = Math.Min(x1, maxX + padX + 1);
            int rBottom = Math.Min(h, y1);
            rects.Add(new Rectangle(rx, ry, rRight - rx, rBottom - ry));
        }
        return rects;
    }

    static int[] FindPeaks(int[] smooth, int count, int minDist)
    {
        var candidates = new List<int[]>();
        for (int x = 20; x < smooth.Length - 20; x++)
        {
            if (smooth[x] < 200) continue;
            bool peak = true;
            for (int k = 1; k <= 16; k++)
            {
                if (smooth[x - k] > smooth[x] || smooth[x + k] > smooth[x])
                {
                    peak = false;
                    break;
                }
            }
            if (peak)
                candidates.Add(new int[] { x, smooth[x] });
        }

        candidates.Sort(delegate(int[] a, int[] b) { return b[1].CompareTo(a[1]); });
        var picked = new List<int>();
        foreach (int[] c in candidates)
        {
            bool far = true;
            foreach (int p in picked)
            {
                if (Math.Abs(p - c[0]) < minDist)
                {
                    far = false;
                    break;
                }
            }
            if (!far) continue;
            picked.Add(c[0]);
            if (picked.Count == count) break;
        }
        picked.Sort();
        return picked.ToArray();
    }

    static int FirstNonZero(int[] s)
    {
        for (int i = 0; i < s.Length; i++)
            if (s[i] > 30) return i;
        return 0;
    }

    static int LastNonZero(int[] s)
    {
        for (int i = s.Length - 1; i >= 0; i--)
            if (s[i] > 30) return i;
        return s.Length - 1;
    }

    static Bitmap PunchCheckerboard(Bitmap src)
    {
        int w = src.Width;
        int h = src.Height;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.DrawImage(src, 0, 0, w, h);
        }

        BitmapData data = bmp.LockBits(
            new Rectangle(0, 0, w, h),
            ImageLockMode.ReadWrite,
            PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);

        bool[] marked = new bool[w * h];
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                if (IsChecker(px[i + 2], px[i + 1], px[i]))
                    marked[y * w + x] = true;
            }
        }

        bool[] kill = new bool[w * h];
        int[] stack = new int[w * h];
        int sp = 0;
        Action<int, int> tryPush = delegate(int x, int y)
        {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            int idx = y * w + x;
            if (!marked[idx] || kill[idx]) return;
            kill[idx] = true;
            stack[sp++] = idx;
        };

        for (int x = 0; x < w; x++)
        {
            tryPush(x, 0);
            tryPush(x, h - 1);
        }
        for (int y = 0; y < h; y++)
        {
            tryPush(0, y);
            tryPush(w - 1, y);
        }

        while (sp > 0)
        {
            int idx = stack[--sp];
            int x = idx % w;
            int y = idx / w;
            tryPush(x - 1, y);
            tryPush(x + 1, y);
            tryPush(x, y - 1);
            tryPush(x, y + 1);
            tryPush(x - 1, y - 1);
            tryPush(x + 1, y - 1);
            tryPush(x - 1, y + 1);
            tryPush(x + 1, y + 1);
        }

        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;
                if (kill[y * w + x] || IsChecker(px[i + 2], px[i + 1], px[i]))
                {
                    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0;
                }
            }
        }

        for (int pass = 0; pass < 6; pass++)
        {
            bool[] extra = new bool[w * h];
            for (int y = 1; y < h - 1; y++)
            {
                int row = y * stride;
                for (int x = 1; x < w - 1; x++)
                {
                    int i = row + x * 4;
                    if (px[i + 3] == 0) continue;
                    if (!IsChecker(px[i + 2], px[i + 1], px[i])) continue;
                    int trans = 0;
                    for (int oy = -1; oy <= 1; oy++)
                        for (int ox = -1; ox <= 1; ox++)
                        {
                            if (ox == 0 && oy == 0) continue;
                            int ni = (y + oy) * stride + (x + ox) * 4;
                            if (px[ni + 3] == 0) trans++;
                        }
                    if (trans >= 2) extra[y * w + x] = true;
                }
            }
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (!extra[y * w + x]) continue;
                    int i = row + x * 4;
                    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0;
                }
            }
        }

        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
        return bmp;
    }

    static Bitmap KeepLargestBlob(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        BitmapData data = src.LockBits(
            new Rectangle(0, 0, w, h),
            ImageLockMode.ReadWrite,
            PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);

        int[] label = new int[w * h];
        int current = 0;
        int bestId = 0, bestCount = 0;
        int[] stack = new int[w * h];

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int start = y * w + x;
                if (label[start] != 0) continue;
                if (px[y * stride + x * 4 + 3] < 16) continue;
                current++;
                int sp = 0;
                stack[sp++] = start;
                label[start] = current;
                int count = 0;
                while (sp > 0)
                {
                    int idx = stack[--sp];
                    int cx = idx % w;
                    int cy = idx / w;
                    count++;
                    for (int oy = -1; oy <= 1; oy++)
                        for (int ox = -1; ox <= 1; ox++)
                        {
                            if (Math.Abs(ox) + Math.Abs(oy) != 1) continue;
                            int nx = cx + ox, ny = cy + oy;
                            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                            int nidx = ny * w + nx;
                            if (label[nidx] != 0) continue;
                            if (px[ny * stride + nx * 4 + 3] < 16) continue;
                            label[nidx] = current;
                            stack[sp++] = nidx;
                        }
                }
                if (count > bestCount)
                {
                    bestCount = count;
                    bestId = current;
                }
            }
        }

        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                if (label[y * w + x] == bestId) continue;
                int i = row + x * 4;
                px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0;
            }
        }

        Marshal.Copy(px, 0, data.Scan0, px.Length);
        src.UnlockBits(data);
        return src;
    }

    static void ScanOpaqueBounds(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        BitmapData data = bmp.LockBits(
            new Rectangle(0, 0, bmp.Width, bmp.Height),
            ImageLockMode.ReadOnly,
            PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * bmp.Height];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);
        for (int y = 0; y < bmp.Height; y++)
        {
            int row = y * stride;
            for (int x = 0; x < bmp.Width; x++)
            {
                if (px[row + x * 4 + 3] < 16) continue;
                if (x < minX) minX = x;
                if (y < minY) minY = y;
                if (x > maxX) maxX = x;
                if (y > maxY) maxY = y;
            }
        }
    }
}
