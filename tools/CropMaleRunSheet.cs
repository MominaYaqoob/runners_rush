using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CropMaleRunSheet
{
    static readonly string Source =
        @"C:\Users\Momina\.cursor\projects\d-runners-rush\assets\c__Users_Momina_AppData_Roaming_Cursor_User_workspaceStorage_20464a88da1297caddbc160bc07a55b0_images_image-fff377e4-038d-49e6-b8c9-ab6628a2bad0.jpg";
    static readonly string Images = @"d:\runners_rush\assets\images";

    static readonly string[] FrameNames =
    {
        "male_run_1.png",
        "male_run_2.png",
        "male_run_3.png",
        "male_run_4.png",
    };
    static readonly int[] FrameCols = { 0, 1, 0, 1 };
    static readonly int[] FrameRows = { 0, 0, 1, 1 };

    public static void Main()
    {
        if (!File.Exists(Source))
            throw new FileNotFoundException("Sprite sheet not found", Source);

        using (var src = new Bitmap(Source))
        {
            int cellW = src.Width / 2;
            int cellH = src.Height / 2;
            Console.WriteLine("sheet " + src.Width + "x" + src.Height + "  cell " + cellW + "x" + cellH);

            var punched = new Bitmap[4];
            for (int i = 0; i < FrameNames.Length; i++)
            {
                int col = FrameCols[i];
                int row = FrameRows[i];
                using (var cell = src.Clone(
                    new Rectangle(col * cellW, row * cellH, cellW, cellH),
                    PixelFormat.Format32bppArgb))
                {
                    punched[i] = PunchCheckerboard(cell);
                }
            }

            int minX = cellW, minY = cellH, maxX = 0, maxY = 0;
            foreach (var bmp in punched)
            {
                ScanOpaqueBounds(bmp, ref minX, ref minY, ref maxX, ref maxY);
            }
            int pad = 8;
            minX = Math.Max(0, minX - pad);
            minY = Math.Max(0, minY - pad);
            maxX = Math.Min(cellW - 1, maxX + pad);
            maxY = Math.Min(cellH - 1, maxY + pad);
            int cw = maxX - minX + 1;
            int ch = maxY - minY + 1;
            Console.WriteLine("shared crop " + cw + "x" + ch);

            var cropped = new Bitmap[4];
            for (int i = 0; i < punched.Length; i++)
            {
                cropped[i] = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
                using (var g = Graphics.FromImage(cropped[i]))
                {
                    g.Clear(Color.Transparent);
                    g.DrawImage(
                        punched[i],
                        new Rectangle(0, 0, cw, ch),
                        new Rectangle(minX, minY, cw, ch),
                        GraphicsUnit.Pixel);
                }
                punched[i].Dispose();
                string outPath = Path.Combine(Images, FrameNames[i]);
                cropped[i].Save(outPath, ImageFormat.Png);
                Console.WriteLine("wrote " + FrameNames[i] + " " + cw + "x" + ch);
            }

            string preview = Path.Combine(Images, "male_run.png");
            cropped[0].Save(preview, ImageFormat.Png);
            Console.WriteLine("wrote male_run.png (preview from frame 1)");

            using (var sheet = new Bitmap(cw * 2, ch * 2, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(sheet))
            {
                g.Clear(Color.Transparent);
                g.DrawImage(cropped[0], 0, 0);
                g.DrawImage(cropped[1], cw, 0);
                g.DrawImage(cropped[2], 0, ch);
                g.DrawImage(cropped[3], cw, ch);
                sheet.Save(Path.Combine(Images, "male_run_sheet.png"), ImageFormat.Png);
                Console.WriteLine("wrote male_run_sheet.png " + sheet.Width + "x" + sheet.Height);
            }

            foreach (var bmp in cropped) bmp.Dispose();
        }
    }

    static bool IsChecker(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int chroma = max - min;
        int avg = (r + g + b) / 3;
        return chroma <= 48 && avg >= 48 && avg <= 235;
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
                if (!kill[y * w + x]) continue;
                int i = row + x * 4;
                px[i] = 0;
                px[i + 1] = 0;
                px[i + 2] = 0;
                px[i + 3] = 0;
            }
        }

        for (int pass = 0; pass < 5; pass++)
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

        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
        return bmp;
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
