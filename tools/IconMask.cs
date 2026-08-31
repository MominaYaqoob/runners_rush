using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class IconMask
{
    public static void Main(string[] args)
    {
        string input = args.Length > 0 ? args[0] : @"d:\runners_rush\assets\images\app_icon_src.png";
        string output = args.Length > 1 ? args[1] : @"d:\runners_rush\assets\images\app_icon.png";
        ConvertFile(input, output);
        Console.WriteLine("Wrote " + output);
    }

    static bool IsChecker(byte r, byte g, byte b)
    {
        int chroma = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        int avg = (r + g + b) / 3;
        return chroma <= 48 && avg >= 70 && avg <= 220;
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
                    marked[y * w + x] = IsChecker(px[i + 2], px[i + 1], px[i]);
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

            int minX = w, minY = h, maxX = 0, maxY = 0;
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    if (kill[y * w + x]) continue;
                    if (x < minX) minX = x;
                    if (y < minY) minY = y;
                    if (x > maxX) maxX = x;
                    if (y > maxY) maxY = y;
                }
            }

            int inset = 3;
            minX += inset;
            minY += inset;
            maxX -= inset;
            maxY -= inset;
            float left = minX;
            float top = minY;
            float rw = maxX - minX + 1;
            float rh = maxY - minY + 1;
            float radius = Math.Min(rw, rh) * 0.22f;
            Console.WriteLine("mask rect " + minX + "," + minY + " " + rw + "x" + rh + " r=" + radius);

            using (var maskBmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(maskBmp))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.Clear(Color.Transparent);
                    using (var path = RoundedRect(left, top, rw, rh, radius))
                    using (var brush = new SolidBrush(Color.White))
                    {
                        g.FillPath(brush, path);
                    }
                }

                BitmapData maskData = maskBmp.LockBits(
                    new Rectangle(0, 0, w, h),
                    ImageLockMode.ReadOnly,
                    PixelFormat.Format32bppArgb);
                byte[] mask = new byte[Math.Abs(maskData.Stride) * h];
                Marshal.Copy(maskData.Scan0, mask, 0, mask.Length);
                int maskStride = Math.Abs(maskData.Stride);

                for (int y = 0; y < h; y++)
                {
                    int row = y * stride;
                    int mrow = y * maskStride;
                    for (int x = 0; x < w; x++)
                    {
                        int i = row + x * 4;
                        byte a = mask[mrow + x * 4 + 3];
                        if (a == 0 || kill[y * w + x])
                        {
                            px[i] = 0;
                            px[i + 1] = 0;
                            px[i + 2] = 0;
                            px[i + 3] = 0;
                        }
                        else
                        {
                            px[i + 3] = a;
                        }
                    }
                }

                maskBmp.UnlockBits(maskData);
            }

            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);
            bmp.Save(output, ImageFormat.Png);
            bmp.Dispose();
        }
    }

    static GraphicsPath RoundedRect(float x, float y, float w, float h, float r)
    {
        r = Math.Min(r, Math.Min(w, h) / 2f);
        var path = new GraphicsPath();
        float d = r * 2f;
        path.AddArc(x, y, d, d, 180, 90);
        path.AddArc(x + w - d, y, d, d, 270, 90);
        path.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        path.AddArc(x, y + h - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}
