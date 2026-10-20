export const webConfig = [
  {
    orden: 1,
    seccion: "hero",
    origen: ["1. QUIÉNES SOMOS"],
    contenido: {
      marca: "ELECCON SOLUTIONS",
      lema: "Siempre conectados",
      titulo: "Infraestructura Eléctrica & Mantenimiento Integral",
      texto: "En Eleccon Solutions, nos especializamos en la ingeniería, construcción y mantenimiento de infraestructuras eléctricas industriales y sistemas de iluminación pública."
    },
    objetivo: "Presentar inmediatamente qué es ELECCON y cuál es su actividad principal."
  },

  {
    orden: 2,
    seccion: "presentacion",
    origen: [
      "1. QUIÉNES SOMOS",
      "8. SERVICIOS ELÉCTRICOS COMPLEMENTARIOS"
    ],
    contenido: {
      titulo: "Experiencia, calidad y seguridad",
      textos: [
        "Nuestro equipo técnico altamente capacitado trabaja bajo estrictos estándares de calidad y seguridad, asegurando resultados óptimos en cada proyecto.",
        "Entendemos la importancia de cumplir con los plazos y presupuestos establecidos, y nos comprometemos a entregar un trabajo de alta calidad que cumpla con todos los estándares de seguridad y normativas vigentes.",
        "Nuestra experiencia nos permite adaptarnos a las necesidades específicas de cada proyecto, ofreciendo soluciones personalizadas y garantizando la satisfacción total del cliente."
      ]
    },
    objetivo: "Generar confianza antes de entrar al detalle de servicios."
  },

  {
    orden: 3,
    seccion: "areas_principales",
    origen: [
      "2. INFRAESTRUCTURA ELÉCTRICA Y MANTENIMIENTO INTEGRAL",
      "3. DISTRIBUCIÓN ELÉCTRICA DOMICILIARIA",
      "4. MANTENIMIENTO DE LUMINARIAS LED EN VÍA PÚBLICA",
      "5. OBRAS PÚBLICAS DE REDES ELÉCTRICAS Y MANTENIMIENTO",
      "6. CONSTRUCCIÓN Y REMODELACIÓN"
    ],
    contenido: {
      titulo: "Nuestras áreas de trabajo",
      introduccion: "Eleccon Solutions brinda servicios vinculados a infraestructura eléctrica y mantenimiento integral, contemplando instalaciones domiciliarias, industriales, comerciales, obras públicas, redes eléctricas, iluminación y mantenimiento.",
      items: [
        {
          titulo: "Distribución Eléctrica Domiciliaria",
          texto: "Brindamos soluciones integrales para instalaciones eléctricas en viviendas unifamiliares, edificios y barrios cerrados, cumpliendo con todas las normativas técnicas y de seguridad vigentes."
        },
        {
          titulo: "Mantenimiento de Luminarias LED",
          texto: "Ofrecemos servicios especializados en el mantenimiento preventivo y correctivo de luminarias LED en espacios públicos, garantizando un funcionamiento eficiente y seguro del sistema de iluminación urbana."
        },
        {
          titulo: "Obras Públicas de Redes Eléctricas y Mantenimiento",
          texto: "Contamos con amplia experiencia en la ejecución de obras públicas vinculadas a la infraestructura eléctrica, abarcando desde la instalación de redes hasta su mantenimiento continuo."
        },
        {
          titulo: "Respuesta Rápida y Continuidad del Servicio",
          texto: "Reducimos los tiempos de intervención para restablecer la operación en el menor tiempo posible. Brindamos respuesta ante incidencias eléctricas y soporte operativo las 24 horas, minimizando tiempos de inactividad y afectaciones al servicio."
        }
      ]
    },
    objetivo: "Mostrar primero las grandes capacidades de ELECCON, evitando abrir la web con una lista enorme de trabajos."
  },

  {
    orden: 4,
    seccion: "proyectos",
    origen: ["Contenido dinámico de proyectos"],
    contenido: {
      titulo: "Proyectos",
      tipo: "dinamico",
      api: "/api/constructora/public/proyectos"
    },
    objetivo: "Dar protagonismo temprano a las obras reales como evidencia de capacidad. Esta sección se alimenta de la API y no modifica el contenido institucional."
  },

  {
    orden: 5,
    seccion: "infraestructura_electrica",
    origen: [
      "3. DISTRIBUCIÓN ELÉCTRICA DOMICILIARIA",
      "8. SERVICIOS ELÉCTRICOS COMPLEMENTARIOS"
    ],
    contenido: {
      titulo: "Infraestructura eléctrica",
      servicios: [
        {
          titulo: "Proyecto e ingeniería eléctrica",
          texto: "Diseño de circuitos según necesidades del espacio y normativa."
        },
        {
          titulo: "Instalación completa",
          texto: "Canalizaciones, cableado, tomas, iluminación, tablero principal y secundarios."
        },
        {
          titulo: "Reacondicionamiento de instalaciones existentes",
          texto: "Actualización de instalaciones antiguas para adaptarlas a los requerimientos actuales."
        },
        {
          titulo: "Protección y seguridad",
          texto: "Instalación de disyuntos, térmicas, puesta a tierra y sistemas de protección diferencial."
        },
        {
          titulo: "Iluminación interior y exterior",
          texto: "Planificación eficiente del consumo, estética y funcionalidad."
        },
        {
          titulo: "Verificación y puesta en marcha",
          texto: "Mediciones, control de fugas y testeo de funcionamiento de todo el sistema."
        }
      ],
      complementarios: [
        "Electricidad: Instalación domiciliaria.",
        "Instalaciones industriales y comerciales.",
        "Tableros, mantenimiento y reparaciones.",
        "Comandas automáticos, porteros eléctricos.",
        "Trabajos en vía, y otros trabajos lo que nos permite abordar proyectos integrales con eficiencia y profesionalismo."
      ]
    },
    objetivo: "Profundizar en la especialidad eléctrica después de haber demostrado visualmente la capacidad de la empresa."
  },

  {
    orden: 6,
    seccion: "obra_publica",
    origen: [
      "4. MANTENIMIENTO DE LUMINARIAS LED EN VÍA PÚBLICA",
      "5. OBRAS PÚBLICAS DE REDES ELÉCTRICAS Y MANTENIMIENTO"
    ],
    contenido: {
      titulo: "Obras públicas y mantenimiento",
      texto: "Trabajamos en colaboración con organismos estatales, cumpliendo con los estándares técnicos y normativos requeridos.",
      servicios: [
        "Tendidos eléctricos de baja y media tensión (aéreos y subterráneos).",
        "Montaje de columnas, tableros y puntos de conexión.",
        "Instalación de sistemas de iluminación urbana y semaforización.",
        "Mantenimiento preventivo y correctivo de redes existentes.",
        "Instalación de nuevos suministros domiciliarios y comerciales.",
        "Corte y reposición del servicio por cuestiones administrativas (como falta de pago).",
        "Atención de reclamos técnicos mediante cuadrillas equipadas para intervenciones.",
        "Inspecciones técnicas periódicas.",
        "Recambio y reposición de artefacto.",
        "Limpieza de luminarias y estructuras.",
        "Reparación de cableado y conexiones.",
        "Adecuación a nuevas tecnologías y normas vigentes."
      ],
      destacado: "Operativos de emergencia con personal disponible las 24 hs."
    },
    objetivo: "Presentar como bloque propio una de las capacidades más fuertes y diferenciadoras de ELECCON."
  },

  {
    orden: 7,
    seccion: "construccion",
    origen: [
      "6. CONSTRUCCIÓN Y REMODELACIÓN",
      "7. NUESTROS SERVICIOS"
    ],
    contenido: {
      titulo: "Construcción y Remodelación",
      introduccion: "Nuestro equipo está altamente capacitado en una variedad de oficios esenciales para su proyecto.",
      categorias: [
        {
          titulo: "Plomería",
          texto: "Reparación de griferías, cañerías, cloacas, pluvial, instalación de artefactos sanitarios, limpieza e instalación de tanques, cisternas y reservas, colocación de calefón y termotanque, destapación de cañerías."
        },
        {
          titulo: "Gas",
          texto: "Instalación de artefactos a gas, habilitación in situ por fuga, planos y mencionamientos de cañería, pedidos y colocación de medidores, proyectos de obras nuevas."
        },
        {
          titulo: "Climatización",
          texto: "Reparación, mantenimiento domiciliario de multisplit y centrales, carga de gas entre otros."
        },
        {
          titulo: "Pintura",
          texto: "Enduido, latex, sintético, acrílico, laca, barniz, satinado al agua."
        },
        {
          titulo: "Trabajos de filtraciones e impermeabilización",
          texto: "Aplicación de tarquín y revear, trabajos en silleteros."
        },
        {
          titulo: "Construcción",
          texto: "Replanteo y construcción, revoques en paredes, colocación de cerámicas, porcelanatos, mosaicos y piedras, mampostería. Además, somos expertos en la instalación de durlock, cielo raso, tabiques, revestimientos."
        },
        {
          titulo: "Aberturas",
          texto: "Puertas y ventanas, techo de chapa, policarbonato y tejas."
        }
      ],
      otros: [
        "Sistema de alarma y cámaras de vigilancia.",
        "Parrillas y chimeneas.",
        "Atención a consorcios.",
        "Construcción llave en mano."
      ]
    },
    objetivo: "Mantener la amplitud de servicios del informe sin competir con la especialización eléctrica en la parte superior de la web."
  },

  {
    orden: 8,
    seccion: "seguridad",
    origen: [
      "9. NUESTRAS POLÍTICAS",
      "10. CALIDAD, SEGURIDAD Y COMPROMISO"
    ],
    contenido: {
      titulo: "Calidad, seguridad y compromiso",
      introduccion: "En Eleccon Solutions trabajamos con un fuerte compromiso hacia la calidad, la seguridad y la mejora continua, alineando nuestras prácticas con estándares reconocidos a nivel nacional e internacional.",
      pilares: [
        {
          titulo: "Calidad Certificada",
          texto: "Aplicamos procedimientos bajo lineamientos de la norma ISO 9001, asegurando trazabilidad, eficiencia y excelencia en cada uno de nuestros servicios."
        },
        {
          titulo: "Seguridad e Higiene",
          texto: "Priorizamos la integridad física de nuestros trabajadores y el entorno, mediante planes de seguridad laboral, capacitaciones constantes y cumplimiento estricto de normativas vigentes."
        },
        {
          titulo: "Enfoque al Cliente",
          texto: "Desarrollamos soluciones que se adaptan a las necesidades de cada proyecto, optimizando tiempos, recursos sin comprometer la calidad."
        },
        {
          titulo: "Cultura de Trabajo Sostenible",
          texto: "Fomentamos el desarrollo profesional del equipo humano y el compromiso con la comunidad, promoviendo prácticas responsables y sustentables."
        }
      ]
    },
    objetivo: "Usar seguridad y calidad como prueba de profesionalismo, no como información secundaria escondida en el footer."
  },

  {
    orden: 9,
    seccion: "reglas_de_oro",
    origen: ["9. NUESTRAS POLÍTICAS"],
    contenido: {
      titulo: "Las 5 reglas de oro en instalaciones eléctricas",
      reglas: [
        {
          titulo: "Desconectar",
          texto: "Corte visible o aislamiento efectivo de todas las fuentes de energía."
        },
        {
          titulo: "Bloqueo",
          texto: "Impedir cualquier reconexión mediante dispositivos de bloqueo."
        },
        {
          titulo: "Verificar",
          texto: "Comprobar la ausencia de tensión."
        },
        {
          titulo: "Puesta a tierra",
          texto: "Poner a tierra y en cortocircuito cuando corresponda."
        },
        {
          titulo: "Señalización",
          texto: "Delimitar y señalizar la zona de trabajo mediante elementos visibles de seguridad."
        }
      ]
    },
    objetivo: "Convertir las políticas técnicas del informe en un elemento visual reconocible."
  },

  {
    orden: 10,
    seccion: "contacto",
    origen: ["11. INFORMACIÓN DE CONTACTO"],
    contenido: {
      titulo: "Contacto",
      contactos_por_verificar: [
        // {
        //   origen: "Contactanos",
        //   correo: "MARISSAESC-00@HOTMAIL.COM",
        //   telefono: "11 2554 1748"
        // },
        {
          origen: "Director de Ventas",
          correo: "VILLARROEL@ELECCON.COM",
          telefono_whatsapp: "11 2839-2623"
        }
      ]
    },
    objetivo: "Cerrar la experiencia con los medios de contacto existentes, manteniéndolos separados hasta confirmar cuál es el oficial."
  }
];