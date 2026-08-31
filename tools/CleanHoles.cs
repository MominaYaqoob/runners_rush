using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CleanHoles
{
    public static void Main(string[] args)
    {
        string dir = args.Length > 0 ? args[0] : @"d:\runners_rush\assets\images";
        string[] names = {
            "male_run.png", "male_jump.png", "male_win.png",
            "male_fall.png", "female_run.png", "female_jump.png", "female_fall.png",
            "characters_duo.png"
        };
        foreach (string name in names)
        {
            string path = Path.Combine(dir, name);
            if (!File.Exists(path)) continue;
            Console.WriteLine("Cleaning holes " + name);
            Clean(path);
        }
    }

    static bool IsGray(byte r, byte g, byte b, byte a, int chromaMax, int minAvg, int maxAvg)
    {
        if (a < 16) return false;
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        return chroma <= chromaMax && avg >= minAvg && avg <= maxAvg;
    }

    static void Clean(string path)
    {
        string work = path + ".work.png";
        File.Copy(path, work, true);

        using (var src = new Bitmap(work))
        {
            int w = src.Width;
            int h = src.Height;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var gfx = Graphics.FromImage(bmp))
            {
                gfx.DrawImage(src, 0, 0, w, h);
            }

            BitmapData data = bmp.LockBits(
                new Rectangle(0, 0, w, h),
                ImageLockMode.ReadWrite,
                PixelFormat.Format32bppArgb);

            int stride = Math.Abs(data.Stride);
            byte[] px = new byte[stride * h];
            Marshal.Copy(data.Scan0, px, 0, px.Length);

            bool[] punch = new bool[w * h];
            int radius = 10;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    int i = row + x * 4;
                    byte a = px[i + 3];
                    byte r = px[i + 2];
                    byte g = px[i + 1];
                    byte b = px[i];
                    if (!IsGray(r, g, b, a, 26, 62, 205)) continue;

                    int light = 0, dark = 0;
                    int y0 = Math.Max(0, y - radius);
                    int y1 = Math.Min(h - 1, y + radius);
                    int x0 = Math.Max(0, x - radius);
                    int x1 = Math.Min(w - 1, x + radius);
                    for (int yy = y0; yy <= y1; yy++)
                    {
                        int rr = yy * stride;
                        for (int xx = x0; xx <= x1; xx++)
                        {
                            int ni = rr + xx * 4;
                            byte na = px[ni + 3];
                            byte nr = px[ni + 2];
                            byte ng = px[ni + 1];
                            byte nb = px[ni];
                            if (!IsGray(nr, ng, nb, na, 30, 55, 220)) continue;
                            int avg = (nr + ng + nb) / 3;
                            if (avg >= 145) light++;
                            else if (avg <= 125) dark++;
                        }
                    }

                    // Real checkerboard has both light and dark gray squares nearby.
                    if (light >= 8 && dark >= 8) punch[y * w + x] = true;
                }
            }

            int removed = 0;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    if (!punch[y * w + x]) continue;
                    int i = row + x * 4;
                    px[i] = 0;
                    px[i + 1] = 0;
                    px[i + 2] = 0;
                    px[i + 3] = 0;
                    removed++;
                }
            }

            // Eat leftover gray fringes next to newly transparent pixels.
            for (int pass = 0; pass < 2; pass++)
            {
                bool[] extra = new bool[w * h];
                for (int y = 1; y < h - 1; y++)
                {
                    int row = y * stride;
                    for (int x = 1; x < w - 1; x++)
                    {
                        int i = row + x * 4;
                        if (px[i + 3] == 0) continue;
                        if (!IsGray(px[i + 2], px[i + 1], px[i], px[i + 3], 32, 58, 210)) continue;
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
                        if (trans >= 3) extra[y * w + x] = true;
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
                        removed++;
                    }
                }
            }

            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);
            Console.WriteLine("  punched " + removed + " checkerboard pixels");

            string temp = path + ".tmp.png";
            bmp.Save(temp, ImageFormat.Png);
            bmp.Dispose();
            File.Copy(temp, path, true);
            File.Delete(temp);
        }
        File.Delete(work);
    }
}
