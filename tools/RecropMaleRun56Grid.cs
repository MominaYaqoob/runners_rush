using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

/// Fixed-grid recrop of male_run_5 / male_run_6 from a 3-top + 4-bottom sheet.
public static class RecropMaleRun56Grid
{
    static readonly string Source =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-6151c3bc-154d-4113-b008-0000247edcf9.jpg";
    static readonly string Images = @"d:\runners_rush\assets\images";
    const int CanvasW = 431;
    const int CanvasH = 472;
    const int Pad = 12;

    public static void Main()
    {
        using (var src = new Bitmap(Source))
        {
            Console.WriteLine("sheet " + src.Width + "x" + src.Height);
            // Bottom row: 4 equal cells. Frames 5 and 6 = columns 1 and 2 (0-based).
            int topH = (int)(src.Height * 0.53); // approx split; refine via gap
            topH = FindRowGap(src);
            Console.WriteLine("row gap y=" + topH);

            int botY = topH;
            int botH = src.Height - botY;
            int cellW = src.Width / 4;

            // Slight overlap into neighbors so feet/head aren't clipped at seams.
            int[] cols = { 1, 2 };
            int[] frames = { 5, 6 };
            for (int i = 0; i < cols.Length; i++)
            {
                int col = cols[i];
                int x0 = Math.Max(0, col * cellW - 12);
                int x1 = Math.Min(src.Width, (col + 1) * cellW + 12);
                int y0 = Math.Max(0, botY - 8);
                int y1 = src.Height;
                var cellRect = Rectangle.FromLTRB(x0, y0, x1, y1);
                Console.WriteLine("frame " + frames[i] + " cell " + cellRect);

                using (var cell = src.Clone(cellRect, PixelFormat.Format32bppArgb))
                using (var punched = Punch(cell))
                {
                    int minX = punched.Width, minY = punched.Height, maxX = -1, maxY = -1;
                    ScanBounds(punched, ref minX, ref minY, ref maxX, ref maxY);
                    if (maxX < minX) throw new Exception("empty frame " + frames[i]);

                    // Expand opaque bounds a little so we don't clip hair/toes.
                    minX = Math.Max(0, minX - 4);
                    minY = Math.Max(0, minY - 6);
                    maxX = Math.Min(punched.Width - 1, maxX + 4);
                    maxY = Math.Min(punched.Height - 1, maxY + 6);

                    int cw = maxX - minX + 1;
                    int ch = maxY - minY + 1;
                    Console.WriteLine("  opaque " + cw + "x" + ch);

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
                        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                        g.DrawImage(
                            punched,
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
        BitmapData data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        src.UnlockBits(data);

        int bestY = h / 2, best = int.MaxValue;
        for (int y = h / 3; y < (2 * h) / 3; y++)
        {
            int score = 0;
            for (int x = 0; x < w; x += 2)
            {
                int i = y * stride + x * 4;
                byte b = px[i], g = px[i + 1], r = px[i + 2];
                int chroma = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
                int avg = (r + g + b) / 3;
                // Character / not flat checker
                if (chroma >= 20 || avg < 70) score++;
            }
            if (score < best) { best = score; bestY = y; }
        }
        return bestY;
    }

    static bool IsCheckerOrBg(byte r, byte g, byte b, byte a)
    {
        if (a < 8) return true;
        int chroma = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        int avg = (r + g + b) / 3;
        // checker gray midtones
        if (chroma <= 16 && avg >= 85 && avg <= 180) return true;
        // near-white sheet background
        if (chroma <= 12 && avg >= 200) return true;
        return false;
    }

    static Bitmap Punch(Bitmap src)
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
                if (IsCheckerOrBg(r, g, b, a))
                {
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
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

    static void ScanBounds(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
    {
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);
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
