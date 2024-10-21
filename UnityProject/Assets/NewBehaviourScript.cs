using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NewBehaviourScript : MonoBehaviour
{
    public Shader awesomeShader = null;
    private Material m_renderMaterial;

    void Start()
    {
        if (awesomeShader == null)
        {
            Debug.LogError("no awesome shader.");
            m_renderMaterial = null;
            return;
        }
        m_renderMaterial = new Material(awesomeShader);
        Camera.main.depthTextureMode = DepthTextureMode.Depth;
    }
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, m_renderMaterial);
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
    }
}
