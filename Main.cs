using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;

namespace RefinedRings
{
    [KSPAddon(KSPAddon.Startup.AllGameScenes,false)]
    public class Main : MonoBehaviour
    {
        Camera activeCam = Camera.current;

        public void Start()
        {
            activeCam.gameObject.AddComponent<ImageEffectScript>();
        }

        public void Update()
        { 
            
        }
    }
}
