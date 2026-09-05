using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

/// Crops a 3x2 male run sheet: skips cell 0 (top-left), writes male_run_1..5.
public static class ImportMaleRun5FromSheet
{
    static readonly string SheetPath =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-ca8abd5f-2715-464d-a715-fcde833e56ad.png";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Cols = 3;
    const int Rows = 2;
    const int Pad = 16;

    public static void Main()
    {
        using (var sheet = new Bitmap(SheetPath))
        {
            int cellW = sheet.Width / Cols;
            int cellH = sheet.Height / Rows;
            Console.WriteLine("sheet {0}x{1} cell {2}x{3}", sheet.Width, sheet.Height, cellW, cellH);

            // Cell order: 0 TL skip, then 1,2,3,4,5 → run_1..5
            int[] keep = { 1, 2, 3, 4, 5 };
            var cleared = new Bitmap[keep.Length];
            var bounds = new int[keep.Length][];
            int maxW = 0, maxH = 0;

            for (int i = 0; i < keep.Length; i++)
            {
                int cell = keep[i];
                int col = cell % Cols;
                int row = cell / Cols;
                var rect = new Rectangle(col * cellW, row * cellH, cellW, cellH);
                using (var cellBmp = sheet.Clone(rect, PixelFormat.Format32bppArgb))
                {
                    cleared[i] = ClearWhiteBg(cellBmp);
                    int minX = cleared[i].Width, minY = cleared[i].Height, maxX = -1, maxY = -1;
                    ScanOpaque(cleared[i], ref minX, ref minY, ref maxX, ref maxY);
                    if (maxX < 0) throw new Exception("empty cell " + cell);
                    minX = Math.Max(0, minX - 2);
                    minY = Math.Max(0, minY - 4);
                    maxX = Math.Min(cleared[i].Width - 1, maxX + 2);
                    maxY = Math.Min(cleared[i].Height - 1, maxY + 2);
                    bounds[i] = new int[] { minX, minY, maxX, maxY };
                    int cw = maxX - minX + 1;
                    int ch = maxY - minY + 1;
                    Console.WriteLine("cell {0} opaque {1}x{2}", cell, cw, ch);
                    if (cw > maxW) maxW = cw;
                    if (ch > maxH) maxH = ch;
                }
            }

            maxW += Pad * 2;
            maxH += Pad * 2;
            int targetW = maxW - Pad * 2;
            int targetH = maxH - Pad * 2;
            Console.WriteLine("canvas {0}x{1}", maxW, maxH);

            // Remove old 6-8 frames so only the new cycle remains.
            foreach (var old in new[] {
                "male_run_6.png", "male_run_7.png", "male_run_8.png"
            })
            {
                string p = Path.Combine(OutDir, old);
                if (File.Exists(p))
                {
                    File.Delete(p);
                    Console.WriteLine("deleted " + old);
                }
            }

            for (int i = 0; i < cleared.Length; i++)
            {
                int minX = bounds[i][0], minY = bounds[i][1], maxX = bounds[i][2], maxY = bounds[i][3];
                int cw = maxX - minX + 1;
                int ch = maxY - minY + 1;
                double scale = Math.Min(targetW / (double)cw, targetH / (double)ch);
                int dw = Math.Max(1, (int)Math.Round(cw * scale));
                int dh = Math.Max(1, (int)Math.Round(ch * scale));
                int dx = (maxW - dw) / 2;
                int dy = maxH - Pad - dh; // feet aligned to bottom

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
                    Console.WriteLine("wrote " + name);
                    if (i == 0)
                        canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
                }
                cleared[i].Dispose();
            }
        }
    }

    static bool IsWhiteBg(byte r, byte g, byte b)
    {
        // Near-white sheet background.
        return r >= 245 && g >= 245 && b >= 245;
    }

    static Bitmap ClearWhiteBg(Bitmap src)
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
                if (IsWhiteBg(r, g, b))
                {
                    dPx[i] = dPx[i + 1] = dPx[i + 2] = dPx[i + 3] = 0;
                }
                else
                {
                    // Soften near-white fringe
                    int avg = (r + g + b) / 3;
                    if (avg >= 230 && Math.Abs(r - g) < 12 && Math.Abs(g - b) < 12)
                    {
                        int t = Math.Min(255, (255 - avg) * 8);
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r; dPx[i + 3] = (byte)t;
                    }
                    else
                    {
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r; dPx[i + 3] = a == 0 ? (byte)255 : a;
                    }
                }
            }
        }

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }

    static void ScanOpaque(Bitmap bmp, ref int minX, ref int minY, ref int maxX, ref int maxY)
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
