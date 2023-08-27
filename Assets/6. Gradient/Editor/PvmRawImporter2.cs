using UnityEngine;
using UnityEditor;

using System;
using System.IO;

[UnityEditor.AssetImporters.ScriptedImporter(1, "raw")]
public class PvmRawImporter2 : UnityEditor.AssetImporters.ScriptedImporter
{
    public enum Bits
    {
        Eight = 1,
        Sixteen = 2,
    }

    public int width = 256;
    public int height = 256;
    public int depth = 256;
    public Bits bit = Bits.Eight;
    public int smooth = 3;

    int valueCount
    {
        get { return width * height * depth; }
    }

    int totalSize
    {
        get { return valueCount * (int)bit; }
    }

    int maxValueSize
    {
        get 
        {
            switch (bit)
            {
                case Bits.Eight   : return (int)Byte.MaxValue;
                case Bits.Sixteen : return (int)UInt16.MaxValue;
                default:
                    throw new Exception("bit is wrong.");
            }
        }
    }

    public override void OnImportAsset(UnityEditor.AssetImporters.AssetImportContext ctx)
    {
        try
        {
            var tex3d = GetTexture3D(ctx.assetPath);
            ctx.AddObjectToAsset("Volume", tex3d);
        }
        catch (Exception e)
        {
            Debug.LogException(e);
        }
    }

    Texture3D GetTexture3D(string path)
    {
        var colors = new Color[valueCount];

        ReadVolumeData(path, colors);
        CalcGradients(colors);

        var tex3d = new Texture3D(width, height, depth, TextureFormat.RGBA32, false);
        tex3d.SetPixels(colors, 0);
        tex3d.Apply();

        return tex3d;
    }

    void ReadVolumeData(string path, Color[] colors)
    {
        using (var stream = new FileStream(path, FileMode.Open))
        {
            if (stream.Length != totalSize) 
            { 
                throw new Exception("Data size is wrong."); 
            }

            float a = 1f / maxValueSize;
            var buf = new byte[(int)bit];

            for (int i = 0; i < colors.Length; ++i)
            {
                float value = 0f;
                switch (bit)
                {
                    case Bits.Eight:
                        var b = stream.ReadByte();
                        value = a * b;
                        break;
                    case Bits.Sixteen:
                        stream.Read(buf, 0, 2);
                        value = a * BitConverter.ToUInt16(buf, 0);
                        break;
                }
                colors[i].a = value;
            }
        }
    }

    void CalcGradients(Color[] colors)
    {
        var grads = new Vector3[colors.Length];

        for (int z = 0; z < depth; ++z)
        {
            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
                {
                    var grad = new Vector3(
                        SampleVolume(colors, x + 1, y, z) - SampleVolume(colors, x, y, z),
                        SampleVolume(colors, x, y + 1, z) - SampleVolume(colors, x, y, z),
                        SampleVolume(colors, x, y, z + 1) - SampleVolume(colors, x, y, z));
                    var index = (z * width * height) + (y * width) + x;
                    grads[index] = grad;
                }
            }
        }

        for (int z = 0; z < depth; ++z)
        {
            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
                {
                    var grad = CalcSmoothedGradient(grads, x, y, z);
                    var index = (z * width * height) + (y * width) + x;
                    colors[index].r = (1f + grad.x) * 0.5f;
                    colors[index].g = (1f + grad.y) * 0.5f;
                    colors[index].b = (1f + grad.z) * 0.5f;
                }
            }
        }
    }

    float SampleVolume(Color[] colors, int x, int y, int z)
    {
        if (x < 0) x = 0;
        if (y < 0) y = 0;
        if (z < 0) z = 0;
        if (x >= width)  x = width  - 1;
        if (y >= height) y = height - 1;
        if (z >= depth)  z = depth  - 1;
        var index = (z * width * height) + (y * width) + x;
        return colors[index].a;
    }

    Vector3 CalcSmoothedGradient(Vector3[] grads, int x0, int y0, int z0)
    {
        var sum = Vector3.zero;
        int n = smooth;

        for (int z = z0 - n; z <= z0 + n; ++z)
        {
            if (z < 0 || z >= depth) continue;
            for (int y = y0 - n; y <= y0 + n; ++y)
            {
                if (y < 0 || y >= height) continue;
                for (int x = x0 - n; x <= x0 + n; ++x)
                {
                    if (x < 0 || x >= width) continue;
                    var index = (z * width * height) + (y * width) + x;
                    sum += grads[index];
                }
            }
        }

        return sum.normalized; 
    }
}
