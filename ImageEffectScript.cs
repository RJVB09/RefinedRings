using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;

namespace RefinedRings
{
    [RequireComponent(typeof(Camera))]
    class ImageEffectScript : MonoBehaviour
    {
        [SerializeField]
        private Shader shader;
        private Material material;
        Camera cam;
        //public GameObject sun;
        //public Texture ringMap;

        private void Awake()
        {
            //create a new material with the supplied shader.
            cam = GetComponent<Camera>();
            cam.depthTextureMode = DepthTextureMode.Depth;
            material = new Material(shader);
        }

        private void OnRenderImage(RenderTexture src, RenderTexture dst)
        {
            
            Graphics.Blit(src, dst, material);
        }
    }
    
}
