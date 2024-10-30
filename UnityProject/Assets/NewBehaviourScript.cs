using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NewBehaviourScript : MonoBehaviour
{
    public Material postProMaterial;

    void Start()
    {
        Camera.main.depthTextureMode = DepthTextureMode.DepthNormals;

        // Generate the SSAO sampling kernel with a cosine weighted distribution
        // For the derivation of this, check https://ameye.dev/notes/sampling-the-hemisphere/
        const uint kernelSize = 64;
        Vector4[] samplingKernel = new Vector4[kernelSize];
        for (int i = 0; i < kernelSize; i++)
        {
            float e0 = Random.Range(0.0f, 1.0f);
            float e1 = Random.Range(0.0f, 1.0f);

            float theta = Mathf.Acos(Mathf.Sqrt(e0));
            float phi = 2 * Mathf.PI * e1;

            samplingKernel[i] = new Vector4(
                Mathf.Sin(theta) * Mathf.Cos(phi),
                Mathf.Sin(theta) * Mathf.Sin(phi),
                Mathf.Cos(theta),
                0 // Unused, unity only does float4
            );
        }

        postProMaterial.SetVectorArray("_SamplingKernel", samplingKernel);
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, postProMaterial);
    }

    public float movementSpeed = 10.0f;
    public float lookSpeed = 2.0f;
    public float sprintMultiplier = 2.0f;

    private float yaw = 0.0f;
    private float pitch = 0.0f;

    void Update()
    {
        // Mouse look
        yaw += lookSpeed * Input.GetAxis("Mouse X");
        pitch -= lookSpeed * Input.GetAxis("Mouse Y");
        pitch = Mathf.Clamp(pitch, -90f, 90f);

        transform.eulerAngles = new Vector3(pitch, yaw, 0.0f);

        // Movement
        float speed = movementSpeed;
        if (Input.GetKey(KeyCode.LeftShift))
        {
            speed *= sprintMultiplier;
        }

        Vector3 direction = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));
        direction = transform.TransformDirection(direction);
        transform.position += direction * speed * Time.deltaTime;

        // Vertical movement
        if (Input.GetKey(KeyCode.E))
        {
            transform.position += transform.up * speed * Time.deltaTime;
        }
        if (Input.GetKey(KeyCode.Q))
        {
            transform.position -= transform.up * speed * Time.deltaTime;
        }

        // Set view to world matrix
        Matrix4x4 viewToWorld = Camera.main.worldToCameraMatrix.inverse;
        postProMaterial.SetMatrix("_ViewToWorld", viewToWorld);
        postProMaterial.SetMatrix("_ViewProj", GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false)* Camera.main.worldToCameraMatrix);
        Matrix4x4 invProj = GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false).inverse;
        postProMaterial.SetMatrix("_InvProj", invProj);
        postProMaterial.SetMatrix("_Proj", GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false));
    }
}
