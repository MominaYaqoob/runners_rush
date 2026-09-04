using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class RecropMaleRun56Clean
{
    static readonly string Source =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-6151c3bc-154d-4113-b008-0000247edcf9.jpg";
    static readonly string Images = @"d:\runners_rush\assets\images";
    const int CanvasW = 431;
    const int CanvasH = 472;
    const int Pad = 10;

    public static void Main()
    {
        using (var src = new Bitmap(Source))
        {
            int gap = FindRowGap(src);
            Console.WriteLine("sheet " + src.Width + "x" + src.Height + " gap=" + gap);
            int cellW = src.Width / 4;
            int[] cols = { 1, 2 };
            int[] frames = { 5, 6 };

            for (int i = 0; i < cols.Length; i++)
            {
                int col = cols[i];
                int x0 = col * cellW + 6;
                int x1 = (col + 1) * cellW - 6;
                // Frame 5 reaches farther right (raised knee / forward arm).
                if (frames[i] == 5)
                {
                    x0 = col * cellW + 2;
                    x1 = Math.Min(src.Width, (col + 1) * cellW + 28);
                }
                int y0 = Math.Max(0, gap + 2);
                int y1 = src.Height;
                var rect = Rectangle.FromLTRB(x0, y0, x1, y1);
                Console.WriteLine("frame " + frames[i] + " " + rect);

                using (var cell = src.Clone(rect, PixelFormat.Format32bppArgb))
                using (var clear = ClearBackground(cell))
                {
                    int minX = clear.Width, minY = clear.Height, maxX = -1, maxY = -1;
                    Scan(clear, ref minX, ref minY, ref maxX, ref maxY);
                    if (maxX < 0) throw new Exception("empty " + frames[i]);

                    minX = Math.Max(0, minX - 2);
                    minY = Math.Max(0, minY - 6);
                    maxX = Math.Min(clear.Width - 1, maxX + 2);
                    maxY = Math.Min(clear.Height - 1, maxY + 4);

                    int cw = maxX - minX + 1;
                    int ch = maxY - minY + 1;
                    Console.WriteLine("  opaque " + cw + "x" + ch + " at " + minX + "," + minY);

                    double scale = Math.Min(
                        (CanvasW - Pad * 2) / (double)cw,
                        (CanvasH - Pad * 2) / (double)ch);
                    int dw = Math.Max(1, (int)Math.Round(cw * scale));
                    int dh = Math.Max(1, (int)Math.Round(ch * scale));
                    int dx = (CanvasW - dw) / 2;
                    int dy = CanvasH - Pad - dh;

                    using (var canvas = new Bitmap(CanvasW, CanvasH, PixelFormat.Format32bppArgb))
                    using (var g = Graphics.FromImage(canvas))
                    {
                        g.Clear(Color.Transparent);
                        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        g.DrawImage(
                            clear,
                            new Rectangle(dx, dy, dw, dh),
                            new Rectangle(minX, minY, cw, ch),
                            GraphicsUnit.Pixel);
                        string path = Path.Combine(Images, "male_run_" + frames[i] + ".png");
                        canvas.Save(path, ImageFormat.Png);
                        Console.WriteLine("wrote " + path);
                    }
                }
            }
        }
    }

    static int FindRowGap(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        byte[] px; int stride;
        LockCopy(src, out px, out stride);
        int bestY = h / 2, best = int.MaxValue;
        for (int y = h / 3; y < (2 * h) / 3; y++)
        {
            int score = 0;
            for (int x = 0; x < w; x += 2)
            {
                int i = y * stride + x * 4;
                if (!IsChecker(px[i + 2], px[i + 1], px[i])) score++;
            }
            if (score < best) { best = score; bestY = y; }
        }
        return bestY;
    }

    /// Warm muted brown-gray checker used in this sheet (not neutral gray).
    static bool IsChecker(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        bool warm = r + 8 >= g && g + 8 >= b;
        return warm && chroma <= 30 && avg >= 50 && avg <= 150;
    }

    static Bitmap ClearBackground(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData sData = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dData = dst.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(sData.Stride);
        byte[] sPx = new byte[stride * h];
        byte[] dPx = new byte[stride * h];
        Marshal.Copy(sData.Scan0, sPx, 0, sPx.Length);

        bool[] isBg = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                isBg[y * w + x] = IsChecker(sPx[i + 2], sPx[i + 1], sPx[i]);
            }

        // Flood from edges through checker only.
        bool[] kill = new bool[w * h];
        var q = new Queue<int>();
        Action<int, int> enq = (x, y) =>
        {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            int idx = y * w + x;
            if (kill[idx] || !isBg[idx]) return;
            kill[idx] = true;
            q.Enqueue(idx);
        };
        for (int x = 0; x < w; x++) { enq(x, 0); enq(x, h - 1); }
        for (int y = 0; y < h; y++) { enq(0, y); enq(w - 1, y); }
        int[] ox = { 1, -1, 0, 0 };
        int[] oy = { 0, 0, 1, -1 };
        while (q.Count > 0)
        {
            int cur = q.Dequeue();
            int cx = cur % w, cy = cur / w;
            for (int d = 0; d < 4; d++) enq(cx + ox[d], cy + oy[d]);
        }

        // Largest non-killed component.
        bool[] seen = new bool[w * h];
        List<int> best = new List<int>();
        int[] stack = new int[w * h];
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = y * w + x;
                if (seen[idx] || kill[idx]) { seen[idx] = true; continue; }
                List<int> comp = new List<int>();
                int sp = 0;
                stack[sp++] = idx;
                seen[idx] = true;
                while (sp > 0)
                {
                    int cur = stack[--sp];
                    comp.Add(cur);
                    int cx = cur % w, cy = cur / w;
                    for (int d = 0; d < 4; d++)
                    {
                        int nx = cx + ox[d], ny = cy + oy[d];
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int nidx = ny * w + nx;
                        if (seen[nidx]) continue;
                        seen[nidx] = true;
                        if (kill[nidx]) continue;
                        stack[sp++] = nidx;
                    }
                }
                if (comp.Count > best.Count) best = comp;
            }
        }

        bool[] keep = new bool[w * h];
        foreach (int idx in best) keep[idx] = true;

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                int idx = y * w + x;
                if (!keep[idx])
                {
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
                }
                else
                {
                    dPx[i] = sPx[i];
                    dPx[i + 1] = sPx[i + 1];
                    dPx[i + 2] = sPx[i + 2];
                    dPx[i + 3] = 255;
                }
            }
        }

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }

    static void LockCopy(Bitmap src, out byte[] px, out int stride)
    {
        BitmapData data = src.LockBits(new Rectangle(0, 0, src.Width, src.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = Math.Abs(data.Stride);
        px = new byte[stride * src.Height];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        src.UnlockBits(data);
    }

    static void Scan(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        int w = bmp.Width, h = bmp.Height;
        byte[] px; int stride;
        LockCopy(bmp, out px, out stride);
        for (int y = 0; y < h; y++)
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
