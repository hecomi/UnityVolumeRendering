using UnityEngine;

public class Create3DTex : MonoBehaviour
{
	[SerializeField]
    int size = 16;

    void Start()
    {
        var tex = new Texture3D(size, size, size, TextureFormat.ARGB32, true);
        var colors = new Color[size * size * size];

        float a = 1f / (size - 1);
        int i = 0;
        Color c = Color.white;

        for (int z = 0; z < size; ++z)
        {
            for (int y = 0; y < size; ++y)
            {
                for (int x = 0; x < size; ++x, ++i)
                {
                    c.r = ((x & 1) != 0) ? x * a : 1 - x * a;
                    c.g = ((y & 1) != 0) ? y * a : 1 - y * a;
                    c.b = ((z & 1) != 0) ? z * a : 1 - z * a;
                    colors[i] = c;
                }
            }
        }

        tex.SetPixels(colors);
        tex.Apply();

		var renderer = GetComponent<Renderer>();
        renderer.material.SetTexture("_Volume", tex);
    }
}