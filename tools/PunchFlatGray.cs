using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class PunchFlatGray
{
    public static void Main(string[] args)
    {
        string path = args.Length > 0 ? args[0] : @"d:\runners_rush\assets\images\characters_duo.png";
        Punch(path);
    }

    static bool IsFlatGray(byte r, byte g, byte b, byte a)
    {
        if (a < 16) return false;
        int chroma = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        int avg = (r + g + b) / 3;
        return chroma <= 14 && avg >= 88 && avg <= 155;
    }

    static void Punch(string path)
    {
        using (var src = new Bitmap(path))
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

            bool[] marked = new bool[w * h];
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    int i = row + x * 4;
                    marked[y * w + x] = IsFlatGray(px[i + 2], px[i + 1], px[i], px[i + 3]);
                }
            }

            bool[] seen = new bool[w * h];
            int[] stack = new int[w * h];
            var component = new List<int>(4096);
            int removed = 0;

            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    int start = y * w + x;
                    if (!marked[start] || seen[start]) continue;

                    component.Clear();
                    int sp = 0;
                    stack[sp++] = start;
                    seen[start] = true;

                    while (sp > 0)
                    {
                        int idx = stack[--sp];
                        component.Add(idx);
                        int cx = idx % w;
                        int cy = idx / w;

                        for (int oy = -1; oy <= 1; oy++)
                        {
                            for (int ox = -1; ox <= 1; ox++)
                            {
                                if (ox == 0 && oy == 0) continue;
                                int nx = cx + ox;
                                int ny = cy + oy;
                                if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                                int nidx = ny * w + nx;
                                if (!marked[nidx] || seen[nidx]) continue;
                                seen[nidx] = true;
                                stack[sp++] = nidx;
                            }
                        }
                    }

                    // Large leftover checker squares; skip tiny anti-aliased edge specks.
                    if (component.Count < 12) continue;

                    foreach (int idx in component)
                    {
                        int i = (idx / w) * stride + (idx % w) * 4;
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

            string temp = path + ".tmp.png";
            bmp.Save(temp, ImageFormat.Png);
            bmp.Dispose();
            src.Dispose();
            File.Copy(temp, path, true);
            File.Delete(temp);
            Console.WriteLine("punched " + removed + " flat-gray hole pixels");
            return;
        }
    }
}
