using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

/// Detects each runner on the 3x2 sheet (skip top-left), crops with padding.
public static class ImportMaleRun5Fixed
{
    static readonly string SheetPath =
        @"d:\runners_rush\assets\images\male_run_sheet.png";
    static readonly string OutDir = @"d:\runners_rush\assets\images";
    const int Pad = 20;

    public static void Main()
    {
        using (var sheet = new Bitmap(SheetPath))
        {
            Console.WriteLine("sheet {0}x{1}", sheet.Width, sheet.Height);
            using (var cleared = ClearWhiteBg(sheet))
            {
                var comps = FindComponents(cleared);
                Console.WriteLine("components: " + comps.Count);
                // Sort by row (cy) then column (cx) — 3x2 reading order.
                comps.Sort((a, b) =>
                {
                    int rowA = a.cy < sheet.Height / 2 ? 0 : 1;
                    int rowB = b.cy < sheet.Height / 2 ? 0 : 1;
                    int c = rowA.CompareTo(rowB);
                    if (c != 0) return c;
                    return a.cx.CompareTo(b.cx);
                });

                for (int i = 0; i < comps.Count; i++)
                {
                    var c = comps[i];
                    Console.WriteLine(
                        "comp {0}: ({1},{2})-({3},{4}) center ({5},{6}) size {7}x{8}",
                        i, c.minX, c.minY, c.maxX, c.maxY, c.cx, c.cy,
                        c.maxX - c.minX + 1, c.maxY - c.minY + 1);
                }

                if (comps.Count < 6)
                    throw new Exception("expected 6 characters, got " + comps.Count);

                // Skip index 0 (top-left), use 1..5
                var keep = comps.Skip(1).Take(5).ToList();

                int maxW = 0, maxH = 0;
                foreach (var c in keep)
                {
                    int cw = c.maxX - c.minX + 1;
                    int ch = c.maxY - c.minY + 1;
                    if (cw > maxW) maxW = cw;
                    if (ch > maxH) maxH = ch;
                }
                maxW += Pad * 2;
                maxH += Pad * 2;
                int targetW = maxW - Pad * 2;
                int targetH = maxH - Pad * 2;
                Console.WriteLine("canvas {0}x{1}", maxW, maxH);

                for (int i = 0; i < keep.Count; i++)
                {
                    var c = keep[i];
                    // Extra margin so fists/scarf/boots aren't clipped
                    int minX = Math.Max(0, c.minX - 8);
                    int minY = Math.Max(0, c.minY - 8);
                    int maxX = Math.Min(cleared.Width - 1, c.maxX + 8);
                    int maxY = Math.Min(cleared.Height - 1, c.maxY + 8);
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
                        g.InterpolationMode =
                            System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        g.PixelOffsetMode =
                            System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                        g.DrawImage(
                            cleared,
                            new Rectangle(dx, dy, dw, dh),
                            new Rectangle(minX, minY, cw, ch),
                            GraphicsUnit.Pixel);
                        string name = "male_run_" + (i + 1) + ".png";
                        canvas.Save(Path.Combine(OutDir, name), ImageFormat.Png);
                        Console.WriteLine("wrote {0} from bounds {1},{2} {3}x{4}",
                            name, minX, minY, cw, ch);
                        if (i == 0)
                            canvas.Save(Path.Combine(OutDir, "male_run.png"), ImageFormat.Png);
                    }
                }
            }
        }
    }

    class Comp
    {
        public int minX, minY, maxX, maxY, cx, cy, count;
    }

    static List<Comp> FindComponents(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = Math.Abs(data.Stride);
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        bmp.UnlockBits(data);

        bool[] seen = new bool[w * h];
        var comps = new List<Comp>();
        int[] ox = { 1, -1, 0, 0, 1, 1, -1, -1 };
        int[] oy = { 0, 0, 1, -1, 1, -1, 1, -1 };
        int minPixels = (w * h) / 80; // ignore tiny noise

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = y * w + x;
                if (seen[idx]) continue;
                if (px[y * stride + x * 4 + 3] < 20) { seen[idx] = true; continue; }

                int minX = x, minY = y, maxX = x, maxY = y, count = 0;
                long sumX = 0, sumY = 0;
                var stack = new Stack<int>();
                stack.Push(idx);
                seen[idx] = true;
                while (stack.Count > 0)
                {
                    int cur = stack.Pop();
                    int cx = cur % w, cy = cur / w;
                    count++;
                    sumX += cx; sumY += cy;
                    if (cx < minX) minX = cx;
                    if (cy < minY) minY = cy;
                    if (cx > maxX) maxX = cx;
                    if (cy > maxY) maxY = cy;
                    for (int d = 0; d < 8; d++)
                    {
                        int nx = cx + ox[d], ny = cy + oy[d];
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int nidx = ny * w + nx;
                        if (seen[nidx]) continue;
                        seen[nidx] = true;
                        if (px[ny * stride + nx * 4 + 3] < 20) continue;
                        stack.Push(nidx);
                    }
                }
                if (count < minPixels) continue;
                comps.Add(new Comp
                {
                    minX = minX, minY = minY, maxX = maxX, maxY = maxY,
                    cx = (int)(sumX / count), cy = (int)(sumY / count),
                    count = count
                });
            }
        }

        // Keep the 6 largest (one per cell).
        comps.Sort((a, b) => b.count.CompareTo(a.count));
        if (comps.Count > 6) comps = comps.Take(6).ToList();
        return comps;
    }

    static bool IsWhiteBg(byte r, byte g, byte b)
    {
        return r >= 242 && g >= 242 && b >= 242;
    }

    static Bitmap ClearWhiteBg(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData sData = src.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dData = dst.LockBits(new Rectangle(0, 0, w, h),
            ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
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
                    int avg = (r + g + b) / 3;
                    if (avg >= 228 && Math.Abs(r - g) < 14 && Math.Abs(g - b) < 14)
                    {
                        int t = Math.Min(255, (255 - avg) * 10);
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r; dPx[i + 3] = (byte)t;
                    }
                    else
                    {
                        dPx[i] = b; dPx[i + 1] = g; dPx[i + 2] = r;
                        dPx[i + 3] = a == 0 ? (byte)255 : a;
                    }
                }
            }
        }

        Marshal.Copy(dPx, 0, dData.Scan0, dPx.Length);
        src.UnlockBits(sData);
        dst.UnlockBits(dData);
        return dst;
    }
}
