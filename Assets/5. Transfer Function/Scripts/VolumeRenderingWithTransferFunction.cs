using UnityEngine;

[ExecuteInEditMode]
public class VolumeRenderingWithTransferFunction : MonoBehaviour
{
    const int width = 100;

	[SerializeField]
	Gradient gradient;

#if UNITY_EDITOR
	[SerializeField]
	bool updateTextureInEveryFrame = false;
#endif

    Texture2D texture_;

    void Start()
    {
        UpdateTexture();
    }

    void Update()
    {
#if UNITY_EDITOR
        if (updateTextureInEveryFrame)
        {
            UpdateTexture();
        }
#endif
    }

    [ContextMenu("UpdateTexture")]
    void UpdateTexture()
    {
        texture_ = new Texture2D(width, 1, TextureFormat.ARGB32, false);
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
