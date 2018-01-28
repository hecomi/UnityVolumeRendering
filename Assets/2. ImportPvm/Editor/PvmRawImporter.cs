using UnityEngine;
using UnityEditor;
using UnityEditor.Experimental.AssetImporters;
using System;
using System.IO;

// Now using PvmRawImporter2 in "6. Gradient" section.
// [ScriptedImporter(1, "raw")]
public class PvmRawImporter : ScriptedImporter
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

    int totalSize
    {
        get { return width * height * depth * (int)bit; }
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

    Texture3D GetTexture3D(string path)
    {
        using (var stream = new FileStream(path, FileMode.Open))
        {
            if (stream.Length != totalSize) 
            { 
                throw new Exception("Data size is wrong."); 
            }

            int n = totalSize;
            var colors = new Color[n];
            float a = 1f / maxValueSize;
            var buf = new byte[(int)bit];

            for (int i = 0; i < n; ++i)
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
                colors[i] = new Color(value, value, value, value);
            }

            var tex3d = new Texture3D(width, height, depth, TextureFormat.RGBA32, false);
            tex3d.SetPixels(colors, 0);

            return tex3d;
        }
    }

    public override void OnImportAsset(AssetImportContext ctx)
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
}
