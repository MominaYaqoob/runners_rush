using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class ImportMaleRun8
{
    static readonly string SrcDir =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Pad = 16;

    static readonly string[] Files = {
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-9071e7f5-e967-487a-a1bc-816627d9095a.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-4b0bbde0-62ab-4041-8da6-c9f40493a6e1.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-d51ed3f6-dc7d-43a5-8601-5bdc8800787e.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-faed64fd-feef-417a-8878-a9c267b9698e.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-a4568e4c-3ef9-4cc1-88d9-6df9dccad66c.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-570762f7-bbef-4f77-a67e-b834806b256e.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-24c3be1b-b100-4dd4-aac2-08ae018b3ebe.jpg",
        "c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-e4394b89-b3bf-4b1a-bca1-6b9ce8c9228e.jpg",
    };

    public static void Main()
    {
        var cleared = new Bitmap[Files.Length];
        var bounds = new int[Files.Length][];
        int maxW = 0, maxH = 0;

        for (int i = 0; i < Files.Length; i++)
        {
            string path = Path.Combine(SrcDir, Files[i]);
            using (var src = new Bitmap(path))
            {
                cleared[i] = ClearBgKeepCharacter(src);
                int minX = cleared[i].Width, minY = cleared[i].Height, maxX = -1, maxY = -1;
                Scan(cleared[i], ref minX, ref minY, ref maxX, ref maxY);
                if (maxX < 0) throw new Exception("empty frame " + (i + 1));
                minX = Math.Max(0, minX - 2);
                minY = Math.Max(0, minY - 6);
                maxX = Math.Min(cleared[i].Width - 1, maxX + 2);
                maxY = Math.Min(cleared[i].Height - 1, maxY + 4);
                bounds[i] = new int[] { minX, minY, maxX, maxY };
                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                Console.WriteLine("frame " + (i + 1) + " opaque " + cw + "x" + ch);
                if (cw > maxW) maxW = cw;
                if (ch > maxH) maxH = ch;
            }
        }

        maxW += Pad * 2;
        maxH += Pad * 2;
        int targetH = maxH - Pad * 2;
        int targetW = maxW - Pad * 2;
        Console.WriteLine("canvas " + maxW + "x" + maxH);

        for (int i = 0; i < cleared.Length; i++)
        {
            int minX = bounds[i][0], minY = bounds[i][1], maxX = bounds[i][2], maxY = bounds[i][3];
            int cw = maxX - minX + 1;
            int ch = maxY - minY + 1;
            double scale = Math.Min(targetW / (double)cw, targetH / (double)ch);
            int dw = Math.Max(1, (int)Math.Round(cw * scale));
            int dh = Math.Max(1, (int)Math.Round(ch * scale));
            int dx = (maxW - dw) / 2;
            int dy = maxH - Pad - dh;

            using (var canvas = new Bitmap(maxW, maxH, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(canvas))
            {
                g.Clear(Color.Transparent);
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(
                    cleared[i],
                    new Rectangle(dx, dy, dw, dh),
                    new Rectangle(minX, minY, cw, ch),
                    GraphicsUnit.Pixel);
                string name = "male_run_" + (i + 1) + ".png";
                canvas.Save(Path.Combine(OutDir, name), ImageFormat.Png);
                Console.WriteLine("wrote " + name + " " + dw + "x" + dh);
                if (i == 0)
                    canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
            }
            cleared[i].Dispose();
        }
    }

    /// True for skin/clothes/gear — not gray checker, black plate, or soft shadow.
    static bool IsCharacter(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        if (chroma >= 20) return true;          // colored pixels
        if (chroma >= 12 && avg >= 35 && avg <= 200) return true; // soft skin / muted cloth
        // very dark outline / boot sole with tiny chroma still part of character
        // only if not pure flat black plate
        if (avg <= 25 && chroma >= 6) return true;
        return false;
    }

    static Bitmap ClearBgKeepCharacter(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData sData = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dData = dst.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(sData.Stride);
        byte[] sPx = new byte[stride * h];
        byte[] dPx = new byte[stride * h];
        Marshal.Copy(sData.Scan0, sPx, 0, sPx.Length);

        bool[] fg = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                fg[y * w + x] = IsCharacter(sPx[i + 2], sPx[i + 1], sPx[i]);
            }

        // Edge flood through non-character pixels only.
        bool[] kill = new bool[w * h];
        var q = new Queue<int>();
        Action<int, int> enq = (x, y) =>
        {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            int idx = y * w + x;
            if (kill[idx] || fg[idx]) return;
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

        // Largest remaining character component.
        bool[] seen = new bool[w * h];
        List<int> best = new List<int>();
        int[] stack = new int[w * h];
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = y * w + x;
                if (seen[idx] || kill[idx] || !fg[idx]) { seen[idx] = true; continue; }
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
                        if (kill[nidx] || !fg[nidx]) continue;
                        stack[sp++] = nidx;
                    }
                }
                if (comp.Count > best.Count) best = comp;
            }
        }

        bool[] keep = new bool[w * h];
        foreach (int idx in best) keep[idx] = true;

        // Expand keep by 1px into nearby non-killed pixels to preserve outlines.
        bool[] keep2 = (bool[])keep.Clone();
        for (int y = 1; y < h - 1; y++)
            for (int x = 1; x < w - 1; x++)
            {
                int idx = y * w + x;
                if (keep[idx] || kill[idx]) continue;
                if (keep[(y) * w + (x - 1)] || keep[(y) * w + (x + 1)] ||
                    keep[(y - 1) * w + x] || keep[(y + 1) * w + x])
                    keep2[idx] = true;
            }

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                int idx = y * w + x;
                if (!keep2[idx])
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

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }

    static void Scan(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);
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
