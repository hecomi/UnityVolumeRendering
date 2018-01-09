using UnityEngine;

public class VolumeRenderingWithTransferFunction : MonoBehaviour
{
    const int width = 100;

	[SerializeField]
	Gradient gradient;

    Texture2D texture_;

    void Start()
    {
        UpdateTexture();
    }

    [ContextMenu("UpdateTexture")]
    void UpdateTexture()
    {
        texture_ = new Texture2D(100, 1, TextureFormat.ARGB32, false);
        for (int i = 0; i < width; ++i)
        {
            var t = (float)i / width;
            texture_.SetPixel(i, 0, gradient.Evaluate(t));
        }
        texture_.Apply(false);
        var renderer = GetComponent<Renderer>();
        renderer.sharedMaterial.SetTexture("_Transfer", texture_);
    }
}
