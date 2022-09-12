using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class ImageEffect : MonoBehaviour
{
    [SerializeField]
    private Shader shader;
    private Material material;
    public GameObject sun;
    public Texture ringMap;
    public Vector4[] spheres;

    [Range(1,32)]
    public float _rayLeighFactor = 4;

    [Range(0.01f,1.0f)]
    public float _transmittance = 0.02f;

    public float FOVmult;
    Camera cam;

    private void Awake()
    {
        // Create a new material with the supplied shader.
        cam = GetComponent<Camera>();
        cam.depthTextureMode = DepthTextureMode.Depth;
        material = new Material(shader);
    }

    // OnRenderImage() is called when the camera has finished rendering.
    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        //material.SetVector("_CamPosition", new Vector4(transform.position.x, transform.position.y, transform.position.z, 0));
        material.SetFloat("_farClipPlane", GetComponent<Camera>().farClipPlane);
        material.SetFloat("_nearClipPlane", GetComponent<Camera>().nearClipPlane);
        material.SetFloat("_CamFOV", GetComponent<Camera>().fieldOfView * Mathf.Deg2Rad);
        material.SetTexture("_RingMap", ringMap);


        //Vector3 vec = cam.ScreenToWorldPoint(new Vector3(Input.mousePosition.x, Input.mousePosition.y, cam.nearClipPlane));
        //Vector3 vec0 = cam.ScreenToWorldPoint(new Vector3(0, 0, cam.nearClipPlane));

        /*
        Vector3 cornerDist = cam.ScreenToWorldPoint(new Vector3(0, 0, cam.nearClipPlane)) - cam.transform.position;
        Vector3 widthDist = cam.ScreenToWorldPoint(new Vector3(Screen.width, 0, cam.nearClipPlane)) - cam.transform.position;
        Vector3 heightDist = cam.ScreenToWorldPoint(new Vector3(0, Screen.height, cam.nearClipPlane)) - cam.transform.position;
        //Debug.DrawRay(cam.transform.position, Vector3.Normalize(vec - cam.transform.position),Color.red);
        Debug.DrawRay(cam.transform.position, cornerDist, Color.green);


        //Debug.DrawRay(cam.transform.position, Vector3.Normalize(transform.rotation * Vector3.forward), Color.yellow);

        Vector3 localRight = transform.rotation * Vector3.right;
        Vector3 localUp = transform.rotation * Vector3.up;


        material.SetVector("_localX", localRight);
        material.SetVector("_localY", localUp);
        material.SetVector("_CornerVertexDist", cornerDist);

        Debug.DrawRay(cam.transform.position, localUp, Color.blue);
        Debug.DrawRay(cam.transform.position, localRight, Color.yellow);

        Vector3 uv = localRight * 0.5f + localUp * 0.5f;
        Debug.DrawRay(cam.transform.position, uv, Color.magenta);

        Debug.DrawRay(cam.transform.position, LerpVector(cornerDist,-cornerDist,uv), Color.red);
        */

        Vector3 localRight = transform.rotation * Vector3.right;
        Vector3 localUp = transform.rotation * Vector3.up;
        Vector3 cornerDist = cam.ScreenToWorldPoint(new Vector3(0, 0, cam.nearClipPlane)) - cam.transform.position;
        Vector3 widthDist = cam.ScreenToWorldPoint(new Vector3(Screen.width, 0, cam.nearClipPlane)) - cam.transform.position;

        float clipPlaneHeight = 2 * GetComponent<Camera>().nearClipPlane * Mathf.Tan(0.5f * GetComponent<Camera>().fieldOfView * Mathf.Deg2Rad);
        material.SetVector("_localX", localRight);
        material.SetVector("_localY", localUp);
        material.SetVector("_CornerVertexDist", cornerDist);
        material.SetVector("_WidthVertexDist", widthDist);
        material.SetFloat("_ClipPlaneHeight", clipPlaneHeight);
        material.SetVector("_SunPos", sun.transform.rotation * Vector3.forward * 10000);
        material.SetVectorArray("Spheres", spheres);
        material.SetFloat("_rayLeighFactor", _rayLeighFactor);
        material.SetFloat("_transmittance", _transmittance);


        Debug.DrawRay(cam.transform.position, cornerDist, Color.red,10);
        Debug.DrawRay(cam.transform.position, widthDist, Color.blue,10);

        Vector2 uv = new Vector2(0.5f, 0.5f);

        Debug.DrawRay(cam.transform.position, localUp, Color.magenta);
        Debug.DrawRay(cam.transform.position, LerpVector(cornerDist, widthDist, uv.x) + localUp * clipPlaneHeight * uv.y, Color.green);
        //Debug.Log(clipPlaneHeight);

        //Debug.Log(Vector3.Normalize(cam.ScreenToWorldPoint(new Vector3(0, 0, cam.nearClipPlane)) - cam.transform.position));


        //material.SetFloat("_AspectRatio", Screen.width / Screen.height);
        //material.SetVector("_CamRot", transform.rotation.eulerAngles * Mathf.Deg2Rad);

        Graphics.Blit(src, dst, material);
    }

    Vector3 LerpVector(Vector3 a, Vector3 b, float t)
    {
        return new Vector3(Mathf.Lerp(a.x, b.x, t), Mathf.Lerp(a.y, b.y, t), Mathf.Lerp(a.z, b.z, t));
    }

    Vector3 Mult(Vector3 a, Vector3 b)
    {
        return new Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
    }
}

