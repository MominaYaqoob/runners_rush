using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class SpritePrep
{
    public static void Main(string[] args)
    {
        string dir = args.Length > 0 ? args[0] : @"d:\runners_rush\assets\images";
        string[] names = {
            "male_run", "male_jump", "male_fall",
            "female_run", "female_jump", "female_fall",
            "obstacle", "background_evening", "app_icon", "male_win",
            "characters_duo", "obstacle_2", "obstacle_flying", "ground_texture",
            "coin"
        };
        foreach (string name in names)
        {
            string input = Path.Combine(dir, name + ".jpg");
            if (!File.Exists(input))
            {
                input = Path.Combine(dir, name + ".jfif");
            }
            if (!File.Exists(input))
            {
                Console.WriteLine("SKIP missing " + name);
                continue;
            }
            string output = Path.Combine(dir, name + ".png");
            Console.WriteLine("Converting " + input);
            ConvertFile(input, output);
            Console.WriteLine("Wrote " + output);
        }
    }

    static bool IsBackground(byte r, byte g, byte b, int chromaLimit, int minAvg, int maxAvg)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        return chroma <= chromaLimit && avg >= minAvg && avg <= maxAvg;
    }

    static void ConvertFile(string input, string output)
    {
        using (var src = new Bitmap(input))
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
                    byte b = px[i];
                    byte g = px[i + 1];
                    byte r = px[i + 2];
                    marked[y * w + x] = IsBackground(r, g, b, 24, 95, 195);
                }
            }

            bool[] kill = new bool[w * h];
            int[] stack = new int[w * h];
            int sp = 0;
            Action<int, int> tryPush = (x, y) =>
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
            }

            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (kill[y * w + x])
                    {
                        int i = row + x * 4;
                        px[i] = 0;
                        px[i + 1] = 0;
                        px[i + 2] = 0;
                        px[i + 3] = 0;
                    }
                }
            }

            for (int pass = 0; pass < 3; pass++)
            {
                bool[] extra = new bool[w * h];
                for (int y = 1; y < h - 1; y++)
                {
                    int row = y * stride;
                    for (int x = 1; x < w - 1; x++)
                    {
                        int i = row + x * 4;
                        if (px[i + 3] == 0) continue;
                        byte b = px[i];
                        byte gch = px[i + 1];
                        byte r = px[i + 2];
                        if (!IsBackground(r, gch, b, 36, 85, 205)) continue;
                        int trans = 0;
                        for (int oy = -1; oy <= 1; oy++)
                        {
                            for (int ox = -1; ox <= 1; ox++)
                            {
                                if (ox == 0 && oy == 0) continue;
                                int ni = (y + oy) * stride + (x + ox) * 4;
                                if (px[ni + 3] == 0) trans++;
                            }
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
                        px[i] = 0;
                        px[i + 1] = 0;
                        px[i + 2] = 0;
                        px[i + 3] = 0;
                    }
                }
            }

            int minX = w, minY = h, maxX = 0, maxY = 0;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (px[row + x * 4 + 3] < 16) continue;
                    if (x < minX) minX = x;
                    if (y < minY) minY = y;
                    if (x > maxX) maxX = x;
                    if (y > maxY) maxY = y;
                }
            }

            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);

            int pad = 8;
            minX = Math.Max(0, minX - pad);
            minY = Math.Max(0, minY - pad);
            maxX = Math.Min(w - 1, maxX + pad);
            maxY = Math.Min(h - 1, maxY + pad);
            int cw = maxX - minX + 1;
            int ch = maxY - minY + 1;
            Console.WriteLine("  crop " + cw + "x" + ch + " from " + w + "x" + h);

            using (var cropped = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(cropped))
                {
                    g.DrawImage(bmp, new Rectangle(0, 0, cw, ch), new Rectangle(minX, minY, cw, ch), GraphicsUnit.Pixel);
                }
                cropped.Save(output, ImageFormat.Png);
            }
            bmp.Dispose();
        }
    }
}
