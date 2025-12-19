/****************************************************************************************
 ESTIMACIÓN : EFICIENCIA TÉCNICA DE LA INVERSIÓN PÚBLICA REGIONAL
 MÉTODO     : FRONTERAS ESTOCÁSTICAS (SFA)
 PERIODO    : 2015 – 2024
 AUTOR      : MIGUEL PAREDES
 UBICACIÓN  : D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\ESTIMACIÓN_SFA
****************************************************************************************/

clear all
set more off

*==============================================================
* 1. DIRECCIONAR CARPETA DE TRABAJO
*==============================================================

cd "D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\ESTIMACIÓN_SFA"
pwd
dir

*==============================================================
* 2. IMPORTAR BASE DE DATOS PANEL
*==============================================================
import excel using "DATA_SFA.xlsx", sheet(DATA) firstrow
describe
summarize

encode Región, gen(Region)
*==============================================================
* 3. ETIQUETAR VARIABLES PRINCIPALES
*==============================================================

label var PC      "% proyectos concluidos (PC)"
label var TEI     "Tasa de ejecución presupuestal de inversión (TEI) (%)"
label var IRIPR   "Índice de Resultado de Inversión Pública Regional (IRIPR)"
label var NPROJ   "NPROJ - Total anual de proyectos culminados por región"
label var DUR     "DUR - Meses promedio desde viabilidad hasta culminación"
label var IEPperc "IEPperc - Monto devengado anual de inversión pública per cápita"

label data "Panel regional 2015-2024 - Eficiencia técnica por SFA"

*==============================================================
* 4. DEFINICIÓN CONCEPTUAL DEL MODELO SFA
*==============================================================

/*
OUTPUTS:
 - PC  : Resultados (% proyectos concluidos)
 - TEI : Desempeño (tasa de ejecución presupuestal)

INPUTS:
 - NPROJ   : Gestión de proyectos (cantidad)
 - DUR     : Gestión de proyectos (tiempo)
 - IEPperc : Económica–presupuestal (recursos per cápita)
*/

*==============================================================
* 5. ESTIMACIÓN DE LA FRONTERA ESTOCÁSTICA ORIENTADA AL OUTPUT
*==============================================================
*======================================================
* TRANSFORMACIÓN LOGARÍTMICA AUTOMÁTICA DE INSUMOS
*======================================================

* Suponiendo PC y TEI en 0–100
gen PC01  = PC/100
gen TEI01 = TEI/100

* Índice geométrico
gen IRIPR_geo = sqrt(PC01 * TEI01)*100
label var IRIPR_geo "IRIPR geométrico (PC y TEI)"

* Modelo SFA (orientado al output por defecto)
frontier IRIPR_geo NPROJ DUR IEPperc, distribution(tnormal)
estimates store ET_model
* Mostrar resultados del modelo
estimates dir

estimates table ET_model, stats(N r2_a aic bic) star(.05 .01 .001)

*==============================================================
* 6. PREDICCIÓN DE LA EFICIENCIA TÉCNICA
*==============================================================

* Eficiencia técnica (TE)
predict TE_IRIPR, te

* Ineficiencia técnica (u)
predict IU_IRIPR, u

* Parte determinística del modelo (la frontera estimada)
predict FRONT_IRIPR, xb

* Error estándar de la frontera
predict SEFRONT_IRIPR, stdp

*Exportar los resultados

export excel using "BASE_SFA_FINAL.xlsx", firstrow(variables) replace

*==============================================================
* 7.GRÁFICO DE EVOLUCIÓN DE LA EFICIENCIA POR REGIÓN (LÍNEAS)
*==============================================================
xtset Region Año

xtline TE_IRIPR, ///
    overlay ///
    title("Evolución de la Eficiencia Técnica Regional (IRIPR)") ///
    ytitle("Eficiencia Técnica (TE_IRIPR)") ///
    xtitle("Año")

*******************************************************************************
*1)-ANALISIS GRÁFICO (DE LA EVOLUCIÓN DE LA EFICIENCIA TECNICA DE LOS PIP)
*******************************************************************************
set scheme s1color
xtline TE_IRIPR
graph export "Evolucion_TE_IRIPR_por_region.png", as(png) width(4000) height(2500) replace

set scheme s1color
xtline TE_IRIPR, overlay ///
    title("Evolución de la ET de los PIP") ///
    ytitle("Eficiencia Tecnica PIP", size(medlarge) margin(r+10)) ///
    legend(size(tiny) row(5))
graph export "Evolucion_TE_IRIPR_conjunto.png", as(png) width(5000) height(3000) replace

*Podemos observar en las gráficas que la tasa de mortalidad ha venido presentando tendencia decreciente

*******************************************************************************
*2)-ANALISIS GRÁFICO DE LAS REGRESORAS
*******************************************************************************

* --- Lista de variables a graficar ---
local vars NPROJ DUR IEPperc

foreach v of local vars {
    
    * Etiqueta de la variable (si existe)
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"
    
    * --- 1️-Gráfico individual por región (sin título) ---
    set scheme s1color
    xtline `v', ///
        ytitle("`vlab'", size(small) margin(r+2)) ///
        legend(off)
    graph export "Evolucion_`v'_por_region.png", as(png) width(4000) height(2500) replace

    * --- 2️-Gráfico conjunto (overlay) ---
    set scheme s1color
    xtline `v', overlay ///
        title("Evolución de `vlab' a nivel regional", size(small)) ///
        ytitle("`vlab'", size(small) margin(r+2)) ///
        legend(size(tiny) row(5))
    graph export "Evolucion_`v'_conjunto.png", as(png) width(5000) height(3000) replace
}
	
********************************************************************************
*3)-ANALISIS GRÁFICO DE VARIABILIDAD TE_IRIPR
********************************************************************************
*Variabilidad individual (regiones)
bysort Region: egen TE_IRIPR_mean=mean(TE_IRIPR)
levelsof Region, local(regs)
twoway (connected TE_IRIPR_mean Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
       (scatter TE_IRIPR_mean Region, msymbol(circle_hollow) mcolor(orange_red)) ///
       , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
         xtitle("Región", size(medlarge)) ///
         ytitle("Eficiencia Tecnica media de los PIP", size(medlarge) margin(r+2)) ///
         title("Variabilidad de Eficiencia Tecnica media de los PIP regional", size(medium)) ///
         legend(off)
graph export "Evolucion_TE_IRIPR_variabilidad_individual.png", as(png) width(5000) height(3000) replace

*variabilidad temporal (evolución)
bysort Año: egen TE_IRIPR_mean1=mean(TE_IRIPR)
set scheme s1color
twoway ///
    (connected TE_IRIPR_mean1 Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
    (scatter TE_IRIPR_mean1 Año, msymbol(circle_hollow) mcolor(orange_red)) ///
    , xlabel(2015(1)2024, labsize(small)) ///
      xtitle("Año", size(medlarge)) ///
      ytitle("Eficiencia Tecnica media de la Inversión Pública", size(medlarge) margin(r+2)) ///
      title("Evolución de Eficiencia Tecnica media de la Inversión Pública regional", size(medium)) ///
      legend(off) ///
      graphregion(color(white)) plotregion(fcolor(white) margin(zero))
graph export "Evolucion_TE_IRIPR_variabilidad_temporal.png", as(png) width(5000) height(3000) replace

set scheme s1color
twoway ///
    (connected TE_IRIPR_mean1 Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
    (scatter TE_IRIPR_mean1 Año, msymbol(circle_hollow) mcolor(orange_red) ///
        mlabel(TE_IRIPR_mean1) mlabcolor(orange_red) mlabsize(small)) ///
    , xlabel(2015(1)2024, labsize(small)) ///
      xtitle("Año", size(medlarge)) ///
      ytitle("Eficiencia Tecnica media de la Inversión Pública", size(medlarge) margin(r+2)) ///
      title("Evolución de Eficiencia Tecnica media de la Inversión Pública regional", size(medium)) ///
      legend(off) ///
      graphregion(color(white)) plotregion(fcolor(white) margin(zero))

graph export "Evolucion_TE_IRIPR_variabilidad_temporal.png", as(png) width(5000) height(3000) replace


* Crear variable de etiquetas en porcentaje con 2 decimales
gen TE_IRIPR_mean1_pct = string(TE_IRIPR_mean1*100, "%9.2f") + "%"

* Configuración del esquema
set scheme s1color

* Gráfico con etiquetas
twoway ///
    (connected TE_IRIPR_mean1 Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
    (scatter TE_IRIPR_mean1 Año, msymbol(circle_hollow) mcolor(orange_red) ///
        mlabel(TE_IRIPR_mean1_pct) mlabcolor(orange_red) mlabsize(small) mlabposition(12)) ///
    , xlabel(2015(1)2024, labsize(small)) ///
      xtitle("Año", size(medlarge)) ///
      ytitle("Eficiencia Tecnica media de la Inversión Pública", size(medlarge) margin(r+2)) ///
      title("Evolución de Eficiencia Tecnica media de la Inversión Pública regional", size(medium)) ///
      legend(off) ///
      graphregion(color(white)) plotregion(fcolor(white) margin(zero))

* Exportar gráfico en alta resolución
graph export "Evolucion_TE_IRIPR_variabilidad_temporal.png", as(png) width(5000) height(3000) replace


********************************************************************************
*4)-ANALISIS GRÁFICO DE VARIABILIDAD REGRESORAS
********************************************************************************
local vars TEI PC NPROJ DUR IEPperc
levelsof Region, local(regs)

foreach v of local vars {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"

    * 1️-Variabilidad individual (por región)
    tempvar mean_reg
    bysort Region: egen `mean_reg' = mean(`v')

    twoway ///
        (connected `mean_reg' Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_reg' Region, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
          xtitle("Región", size(medsmall)) ///
          ytitle("`vlab' (media)", size(small) margin(r+8)) ///
          title("Evolución de `vlab' promedio por región", size(small)) ///
          legend(off) ///
          graphregion(color(white)) plotregion(fcolor(white) margin(zero))

    graph export "Evolucion_`v'_por_region.png", as(png) width(4500) height(2800) replace

    * 2️-Variabilidad temporal (promedio anual)
    tempvar mean_year
    bysort Año: egen `mean_year' = mean(`v')

    set scheme s1color
    twoway ///
        (connected `mean_year' Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_year' Año, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(2015(1)2024, labsize(small)) ///
          xtitle("Año", size(medsmall)) ///
          ytitle("`vlab' (media anual)", size(small) margin(r+8)) ///
          title("Evolución anual de `vlab' promedio", size(small)) ///
          legend(off) ///
          graphregion(color(white)) plotregion(fcolor(white) margin(zero))

    graph export "Evolucion_`v'_por_anio.png", as(png) width(4500) height(2800) replace
}


local vars TEI PC NPROJ DUR IEPperc
levelsof Region, local(regs)

foreach v of local vars {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"

    * 1️-Variabilidad individual (por región)
    tempvar mean_reg
    bysort Region: egen `mean_reg' = mean(`v')

    twoway ///
        (connected `mean_reg' Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_reg' Region, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
          xtitle("Región", size(medsmall)) ///
          ytitle("`vlab' (media)", size(small) margin(r+8)) ///
          title("Evolución de `vlab' promedio por región", size(small)) ///
          legend(off) ///
          graphregion(color(white)) plotregion(fcolor(white) margin(zero))

    graph export "Evolucion_`v'_por_region.png", as(png) width(4500) height(2800) replace

* 2️-Variabilidad temporal (promedio anual con etiquetas en % y 2 decimales)
tempvar mean_year
bysort Año: egen `mean_year' = mean(`v')

* Crear variable de etiquetas en porcentaje con 2 decimales
gen `mean_year'_pct = string(`mean_year'*100, "%9.2f") + "%"

set scheme s1color
twoway ///
    (connected `mean_year' Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
    (scatter   `mean_year' Año, mcolor(orange_red) msymbol(circle_hollow) ///
        mlabel(`mean_year'_pct) mlabcolor(orange_red) mlabsize(small) mlabposition(12)) ///
    , xlabel(2015(1)2024, labsize(small)) ///
      xtitle("Año", size(medsmall)) ///
      ytitle("`vlab' (media anual)", size(small) margin(r+8)) ///
      title("Evolución anual de `vlab' promedio", size(small)) ///
      legend(off) ///
      graphregion(color(white)) plotregion(fcolor(white) margin(zero))

graph export "Evolucion_`v'_por_anio.png", as(png) width(4500) height(2800) replace

}

local vars PC TEI
levelsof Region, local(regs)

foreach v of local vars {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"

    * 1️-Variabilidad individual (por región)
    tempvar mean_reg
    bysort Region: egen `mean_reg' = mean(`v')

    twoway ///
        (connected `mean_reg' Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_reg' Region, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
          xtitle("Región", size(medsmall)) ///
          ytitle("`vlab' (media)", size(small) margin(r+4)) ///
          title("Evolución de `vlab' promedio por región", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_region.png", as(png) width(3000) height(2000) replace

    * 2️-Variabilidad temporal (promedio anual con etiquetas en % y 2 decimales)
    tempvar mean_year
    bysort Año: egen `mean_year' = mean(`v')

    gen `mean_year'_pct = string(`mean_year'*100, "%9.2f") + "%"

    set scheme s1color
    twoway ///
        (connected `mean_year' Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_year' Año, mcolor(orange_red) msymbol(circle_hollow) ///
            mlabel(`mean_year'_pct) mlabcolor(orange_red) mlabsize(small) mlabposition(12)) ///
        , xlabel(2015(1)2024, labsize(small)) ///
          xtitle("Año", size(medsmall)) ///
          ytitle("`vlab' (media anual)", size(small) margin(r+4)) ///
          title("Evolución anual de `vlab' promedio", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_anio.png", as(png) width(3000) height(2000) replace
}

*GRÁFICANDO IE CIN CV DP

local vars CIN 
levelsof Region, local(regs)

foreach v of local vars {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"

    * 1️-Variabilidad individual (por región)
    tempvar mean_reg
    bysort Region: egen `mean_reg' = mean(`v')

    twoway ///
        (connected `mean_reg' Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_reg' Region, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
          xtitle("Región", size(medsmall)) ///
          ytitle("`vlab' (media)", size(small) margin(r+4)) ///
          title("Evolución de `vlab' promedio por región", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_region.png", as(png) width(3000) height(2000) replace

    * 2️-Variabilidad temporal (promedio anual con etiquetas en % y 2 decimales)
    tempvar mean_year
    bysort Año: egen `mean_year' = mean(`v')

    gen `mean_year'_pct = string(`mean_year'*100, "%9.2f") + "%"

    set scheme s1color
    twoway ///
        (connected `mean_year' Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_year' Año, mcolor(orange_red) msymbol(circle_hollow) ///
            mlabel(`mean_year'_pct) mlabcolor(orange_red) mlabsize(small) mlabposition(12)) ///
        , xlabel(2015(1)2024, labsize(small)) ///
          xtitle("Año", size(medsmall)) ///
          ytitle("`vlab' (media anual)", size(small) margin(r+4)) ///
          title("Evolución anual de `vlab' promedio", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_anio.png", as(png) width(3000) height(2000) replace
}



* Definir las variables a graficar
local vars IE CV DP  

* Guardar los valores de Región para el eje X
levelsof Region, local(regs)

* Iterar sobre cada variable
foreach v of local vars {
    local vlab : variable label `v'
    if "`vlab'" == "" local vlab "`v'"

    * 1️- Variabilidad por región (promedio regional)
    tempvar mean_reg
    bysort Region: egen `mean_reg' = mean(`v')

    twoway ///
        (connected `mean_reg' Region, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_reg' Region, mcolor(orange_red) msymbol(circle_hollow)) ///
        , xlabel(`regs', valuelabel angle(45) labsize(small)) ///
          xtitle("Región", size(medsmall)) ///
          ytitle("`vlab' (media)", size(small) margin(r+4)) ///
          title("Evolución de `vlab' promedio por región", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_region.png", as(png) width(3000) height(2000) replace

    * 2️- Variabilidad temporal (promedio anual en valores normales con 2 decimales)
    tempvar mean_year
    bysort Año: egen `mean_year' = mean(`v')
    format `mean_year' %9.2f   // etiquetas con 2 decimales

    set scheme s1color
    twoway ///
        (connected `mean_year' Año, lcolor(orange_red) mcolor(orange_red) msymbol(diamond)) ///
        (scatter   `mean_year' Año, mcolor(orange_red) msymbol(circle_hollow) ///
            mlabel(`mean_year') mlabcolor(orange_red) mlabsize(small) mlabposition(12)) ///
        , xlabel(2015(1)2024, labsize(small)) ///
          xtitle("Año", size(medsmall)) ///
          ytitle("`vlab' (media anual)", size(small) margin(r+4)) ///
          title("Evolución anual de `vlab' promedio", size(small)) ///
          legend(off) ///
          graphregion(color(white)) ///
          plotregion(fcolor(white) margin(medium)) ///
          xsize(6) ysize(4)

    graph export "Evolucion_`v'_por_anio.png", as(png) width(3000) height(2000) replace
}


********************************************************************************
*5)-ANALISIS ESTADISTICO DESCRIPTIVO 
********************************************************************************	  

xtsum TEI PC IRIPR NPROJ DUR IEPperc
	
save DATA_SFA_FINAL15DIC2025


*ABRIMOS OTRA BASE

*==============================================================
* 2. IMPORTAR BASE DE DATOS PANEL
*==============================================================
import excel using "DATA_PANEL.xlsx", sheet(DATA) firstrow
describe
summarize

encode Region, gen(Region1) 
drop Region
rename Region1 Region

save DATA_PANEL_FINAL15DIC2025, replace

clear

use DATA_SFA_FINAL15DIC2025
merge m:1 Region Año using DATA_PANEL_FINAL15DIC2025

drop _merge

save DATA_FINALY_PARA_ANALIZAR15DIC2025



