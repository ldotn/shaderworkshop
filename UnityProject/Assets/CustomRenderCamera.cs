using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CustomRenderCamera : MonoBehaviour
{
    public Shader renderShader = null;
    public Camera renderCamera = null;
    public RenderTexture renderTexture = null;
    public Camera mainCamera = null;

    // Start is called before the first frame update
    void Start()
    {
        if (renderCamera == null)
        {
            renderCamera = GetComponent<Camera>();
        }

        if (renderCamera != null && renderShader != null)
        {
            renderCamera.SetReplacementShader(renderShader, "RenderType");
            renderCamera.targetTexture = renderTexture;
        }

        if (mainCamera == null)
        {
            mainCamera = Camera.main;
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (mainCamera != null && renderCamera != null)
        {
            // Copy transformation from main camera
            renderCamera.transform.position = mainCamera.transform.position;
            renderCamera.transform.rotation = mainCamera.transform.rotation;

            // Optionally, copy other properties
            renderCamera.fieldOfView = mainCamera.fieldOfView;
            renderCamera.nearClipPlane = mainCamera.nearClipPlane;
            renderCamera.farClipPlane = mainCamera.farClipPlane;

            // Update render texture size if screen size changes
            if (renderTexture.width != Screen.width || renderTexture.height != Screen.height)
            {
                UpdateRenderTexture();
            }
        }
    }

    void UpdateRenderTexture()
    {
        if (renderTexture != null)
        {
            renderTexture.Release();
        }

        renderTexture = new RenderTexture(Screen.width, Screen.height, 32);
        renderTexture.format = RenderTextureFormat.RGB111110Float;
        renderCamera.targetTexture = renderTexture;
    }
}
