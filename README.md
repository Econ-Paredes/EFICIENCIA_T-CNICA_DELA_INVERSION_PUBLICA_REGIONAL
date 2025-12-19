# EFICIENCIA_TECNICA_DELA_INVERSION_PUBLICA_REGIONAL

## Descripción general

Este repositorio contiene la base de datos procesada y la totalidad de los scripts desarrollados en **Python**, **R** y **Stata** utilizados en la tesis de maestría titulada:

**“Determinantes de la Eficiencia Técnica en la Inversión Pública Regional, Perú, 2015–2024: Un análisis panel con enfoque espacial”**

El repositorio tiene como finalidad garantizar la transparencia, reproducibilidad y trazabilidad de los resultados empíricos obtenidos, permitiendo la replicación independiente de los análisis econométricos y espaciales desarrollados en la investigación.

## Objetivo del repositorio

- Facilitar la replicación de los resultados presentados en la tesis.  
- Promover buenas prácticas de ciencia abierta y ética en investigación.  
- Servir como referencia metodológica para estudios sobre eficiencia técnica, inversión pública, datos panel y econometría espacial aplicada al sector público.

## Estructura del repositorio

├── data/  
│   ├── raw/                # Datos originales de fuentes oficiales  
│   └── processed/          # Bases de datos depuradas y estandarizadas  
│  
├── stata/  
│   ├── sfa/                # Estimación de Frontera Estocástica (SFA)  
│   ├── panel/              # Modelos de datos panel (EF, Driscoll–Kraay)  
│   └── descriptivos/       # Análisis descriptivo  
│  
├── r/  
│   ├── spatial/            # Análisis de dependencia espacial  
│   ├── maps/               # Mapas temáticos  
│   └── utils/              # Funciones auxiliares  
│  
├── outputs/  
│   ├── tables/             # Tablas de resultados  
│   └── figures/            # Figuras y gráficos finales  
│  
└── README.md  

## Metodología resumida

- Modelo principal: Frontera Estocástica de Producción (SFA), orientación al output.  
- Modelos complementarios:  
  - Datos panel con efectos fijos.  
  - Errores estándar robustos Driscoll–Kraay.  
  - Econometría espacial (Índice de Moran y análisis de clústeres).  
- Unidad de análisis: Gobiernos regionales del Perú.  
- Periodo de estudio: 2015–2024.

## Fuentes de datos

Los datos utilizados provienen de fuentes secundarias oficiales, entre ellas:

- Ministerio de Economía y Finanzas (MEF – Consulta Amigable / Invierte.pe).  
- Contraloría General de la República.  
- Organismos nacionales e internacionales de información estadística e institucional.

Todas las bases fueron depuradas, validadas y estandarizadas antes de su uso econométrico.

## Reproducibilidad

Los resultados del estudio pueden reproducirse siguiendo el orden lógico de los scripts:

1. Limpieza y preparación de datos.  
2. Estimación de la eficiencia técnica (SFA).  
3. Modelos explicativos de datos panel.  
4. Análisis de dependencia espacial.  
5. Generación de tablas y figuras finales.

Los scripts se encuentran comentados para facilitar su comprensión y reutilización académica.

## Requisitos de software

- Stata: versión 15 o superior.  
- R: versión 4.0 o superior.

Paquetes principales en R: sf, spdep, tmap, ggplot2, dplyr.

## Autores

Miguel Jesús Armando Paredes Trujillo  
ORCID: 0009-0002-1227-8643  

Yameli Estefani Del Castillo Quispe  
ORCID: 0009-0004-8419-9543  

Asesor:  
Mg. Wilder Pizarro Rodas  

Institución:  
Universidad Nacional del Callao – Escuela de Posgrado  
Facultad de Ciencias Económicas  

## Licencia

Este repositorio se distribuye bajo la licencia **Creative Commons Attribution 4.0 International (CC BY 4.0)**.  
El uso del contenido está permitido siempre que se cite adecuadamente a los autores.

## Nota final

Este repositorio tiene fines académicos y de investigación.  
Cualquier uso del material debe respetar los principios de citación, ética académica y reconocimiento de autoría.
