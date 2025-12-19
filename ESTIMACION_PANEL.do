/****************************************************************************************
* TESIS DE MAESTRÍA
* TÍTULO: Determinantes de la eficiencia técnica de la inversión pública regional
*
* OBJETIVO ECONOMÉTRICO:
*   Estimar el impacto de factores institucionales, presupuestales,
*   operativos y demográficos sobre la eficiencia técnica (ET)
*   de la inversión pública regional, utilizando modelos de datos de panel.
*
* PERIODO DE ANÁLISIS: 2015–2024
* UNIDAD DE ANÁLISIS: Regiones del Perú
*
* SOFTWARE: Stata
****************************************************************************************/

*------------------------------------------------------------*
* 0) DEFINICIÓN DEL DIRECTORIO DE TRABAJO
*------------------------------------------------------------*
cd "D:\MIGUEL PAREDES  M.2\Desktop\MIGUEL PAREDES\MAESTRIA TITULACIÓN\ESTIMACIONES\ESTIMACIÓN_SFA"

* Verificar directorio activo
pwd

* Listar archivos disponibles
dir

*------------------------------------------------------------*
* 1) CARGA DE LA BASE DE DATOS FINAL
*------------------------------------------------------------*
use DATA_FINALY_PARA_ANALIZAR15DIC2025, replace

* Verificación inicial de la base
describe
summarize

/****************************************************************************************
* 2) TRANSFORMACIONES DE VARIABLES
*
* Se aplican transformaciones logarítmicas con dos propósitos:
*   (i) Reducir asimetría y heterocedasticidad
*   (ii) Facilitar la interpretación semi-elástica de los coeficientes
*
* TRATAMIENTO ESPECIAL PARA NPROJ:
*   La variable número de proyectos (NPROJ) presenta valores iguales a cero.
*   Dado que ln(0) es indefinido, se emplea la transformación:
*
*       ln(NPROJ + 1)
*
*   Este artificio es ampliamente utilizado en la literatura aplicada
*   (Wooldridge, 2020; Cameron & Trivedi, 2010) y permite:
*     - Conservar observaciones
*     - Mantener la interpretación económica
****************************************************************************************/
*-- 2.1) Logaritmos estándar (solo si la variable es estrictamente positiva)
foreach x of varlist IEPperc IE DUR CV DP {
    capture confirm variable `x'
    if _rc==0 {
        gen ln`x' = ln(`x')
        label var ln`x' "ln(`x')"
    }
}

*-- 2.2) NPROJ con ceros: usar log(1 + NPROJ) para evitar ln(0)
capture confirm variable NPROJ
if _rc==0 {
    gen lnNPROJ = ln(NPROJ + 1)
    label var lnNPROJ "ln(NPROJ + 1) (ajuste por ceros)"
}

* Verificación de nuevas variables
summarize lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP

/****************************************************************************************
* 3) DEFINICIÓN DE LA ESTRUCTURA DE DATOS DE PANEL
*
* La base corresponde a un panel balanceado:
*   - N = 25 regiones
*   - T = 10 años (panel corto o micropanel)
*
* Esta estructura es adecuada para:
*   - Modelos de efectos fijos / aleatorios
*   - Análisis de eficiencia y desempeño regional

*------------------------------------------------------------*
* 3.1) lista final de variables del modelo (consistencia)
*    Dependiente: ET
*    Explicativas: CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP
*------------------------------------------------------------*

****************************************************************************************/
xtset Region Año
xtdescribe

/****************************************************************************************
* 4) CONSIDERACIONES METODOLÓGICAS PREVIAS
*
* En estudios de datos de panel con horizonte temporal corto (T pequeño),
* la estacionariedad estricta de todas las variables no constituye un
* requisito determinante para la estimación en niveles, especialmente
* cuando el objetivo es explicar variaciones en un indicador de desempeño
* y no modelar relaciones macroeconómicas de largo plazo.
*
* No obstante, se aplican pruebas de raíz unitaria como ejercicio
* complementario de rigor metodológico.
*
* Referencias:
*   - Baltagi (2021)
*   - Wooldridge (2020)
****************************************************************************************/
*------------------------------------------------------------*
* 5) PRUEBAS DE RAÍZ UNITARIA EN PANEL (PRE-ESTIMACIÓN)
* Objetivo: evaluar si las variables del modelo presentan raíz unitaria
*           (no estacionariedad) antes de estimar el panel.
*
* Pruebas empleadas:
*   (1) Im–Pesaran–Shin (IPS): H0 = todos los paneles tienen raíz unitaria
*   (2) Fisher-ADF (Maddala & Wu): H0 = todos los paneles tienen raíz unitaria
*
* Especificaciones:
*   A) Sin tendencia: constante (drift)
*   B) Con tendencia: constante + tendencia determinística
*
* Nota técnica (panel corto):
*   Con T pequeño, la potencia de estos tests puede ser limitada;
*   por ello se reportan como evidencia complementaria de rigor.
*------------------------------------------------------------*

* Lista de variables del modelo (en niveles y en log cuando corresponde)
local Y  ET
local X  CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP

*-- Variables a testear (ajusta si corresponde)
local U `Y' `X'

foreach v of local U {

    di "=================================================="
    di "PRUEBAS DE RAÍZ UNITARIA EN PANEL PARA: `v'"
    di "=================================================="

    *------------------------------------------------------*
    * A) SIN TENDENCIA (drift): incluye constante
    *------------------------------------------------------*
    xtunitroot ips `v'
    xtunitroot fisher `v', dfuller lags(1) drift

    *------------------------------------------------------*
    * B) CON TENDENCIA: incluye tendencia determinística
    *------------------------------------------------------*
    xtunitroot ips `v', trend
    xtunitroot fisher `v', dfuller lags(1) trend

    di ""
}

****************************************************************************************
* 5) PRUEBAS DE ESPECIFICACIÓN Y VALIDACIÓN DEL MODELO PANEL
*
* Estas pruebas NO son "pre-estimación" en sentido estricto.
* Son criterios para:
*   - justificar el uso de estructura panel vs pooled OLS
*   - seleccionar entre Efectos Fijos (FE) y Efectos Aleatorios (RE)
*
* Estructura panel:
*   xtset Region Año
*
* Variable dependiente:
*   ET (eficiencia técnica)
*
* Regresores (determinantes):
*   CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP
****************************************************************************************
*-----------------------------------------------------*
* 5.1) MODELO BASE: MCO AGRUPADO (pooled OLS)
*      (benchmark: ignora heterogeneidad no observada)
*-----------------------------------------------------*
reg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP
estimates store ols

*-----------------------------------------------------*
* (Opcional) Gráfico observado vs. predicho (pooled OLS)
*-----------------------------------------------------*
predict yhat_ols if e(sample), xb

quietly summarize yhat_ols if e(sample), meanonly
local lo = r(min)
local hi = r(max)

* Si por algún motivo el rango sale vacío, forzar rango genérico
if missing(`lo') | missing(`hi') {
    di as error "Advertencia: rango vacío, se aplicará rango genérico (0,1)"
    local lo = 0
    local hi = 1
}

twoway ///
    (scatter ET yhat_ols, msymbol(circle_hollow) msize(vsmall)) ///
    (lfit ET yhat_ols, lwidth(medthick)) ///
    (function y=x, range(`lo' `hi') lpattern(dash)) ///
, ///
    title("Ajuste observado vs. predicho (pooled OLS)") ///
    xtitle("Valor ajustado (ŷ)") ///
    ytitle("Observado (ET)") ///
    legend(order(1 "Observado" 2 "Recta de ajuste" 3 "Línea 45°") cols(1) pos(6) ring(0))

*-----------------------------------------------------*
* 5.2) MODELO DE EFECTOS FIJOS (FE)
*      Controla heterogeneidad inobservable constante por región
*-----------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP, fe
estimates store fe0

*-----------------------------------------------------*
* 5.3) MODELO DE EFECTOS ALEATORIOS (RE)
*      Asume que la heterogeneidad regional NO se correlaciona con X
*-----------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP, re
estimates store re0

*-----------------------------------------------------*
* 5.4) LM Breusch–Pagan (RE vs pooled OLS)
*      H0: var(u)=0 => NO hay efecto panel (OLS suficiente)
*      Si p<0.05 => hay efecto panel => usar FE/RE
*-----------------------------------------------------*
xttest0

*-----------------------------------------------------*
* 5.5) Hausman (FE vs RE)
*      H0: RE es consistente (no correlación entre efectos y X)
*      Si p<0.05 => preferir FE
*      Si p>=0.05 => RE aceptable
*-----------------------------------------------------*
hausman fe0 re0

*-----------------------------------------------------*
* 5.6) Tabla comparativa (OLS vs FE vs RE)
*      Nota: en modelos xtreg el "R2" no es directamente comparable con OLS.
*-----------------------------------------------------*
estimates table ols fe0 re0, star stats(N r2 r2_a)

* Este apartado concluye que la estimaciónd de efectos FE es la más adecuada.
****************************************************************************************
/****************************************************************************************
* APARTADO 6) VALIDACIÓN Y DIAGNÓSTICOS POST-ESTIMACIÓN (MODELO FINAL: EFECTOS FIJOS)
* Unidad de análisis : Región (N=25)
* Periodo            : Año (T=10)
* Variable dependiente (ET): Eficiencia técnica de la inversión pública
* Regresores         : CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP
*
* Nota metodológica clave:
* - En modelos panel (FE), la normalidad de residuos NO es condición necesaria para
*   consistencia. Por ello, la inferencia se realiza con errores estándar robustos
*   (cluster por región y/o correcciones adicionales).
* - Los diagnósticos relevantes aquí son:
*   (i) Efectos de tiempo (shocks comunes) -> testparm i.Año
*   (ii) Heteroscedasticidad groupwise en FE -> xttest3 (Wald modificado)
*   (iii) Correlación serial (AR(1)) -> xtserial (Wooldridge)
*   (iv) Dependencia transversal -> xtcsd (Pesaran CD)
****************************************************************************************/

*------------------------------------------------------------*
* 6.0) Asegurar estructura panel
*------------------------------------------------------------*
xtset Region Año

*------------------------------------------------------------*
* 6.1) Estimación base FE (sin dummies de año) - referencia
*      (NO es el modelo final si hay shocks comunes)
*------------------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP, fe
estimates store FE_base

*------------------------------------------------------------*
* 6.2) ¿Se requieren EFECTOS DE TIEMPO? (FE + dummies por año)
*
* Idea:
* - En panel regional es frecuente que existan shocks nacionales comunes
*   (ciclos macro, reformas, pandemia, cambios presupuestales, etc.)
* - Si los dummies de año son conjuntamente significativos, se recomienda
*   incluir efectos fijos de tiempo (two-way FE: región y año).
*
* H0 (testparm): todos los coeficientes de i.Año = 0 (no se requieren)
* Si p<0.05 -> incluir efectos de tiempo.
*------------------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP i.Año, fe
estimates store FE_tw

testparm i.Año

*------------------------------------------------------------*
* 6.3) HETEROSCEDASTICIDAD en FE (groupwise)
*
* Prueba recomendada para FE:
* - xttest3: Wald modificado para heteroscedasticidad entre paneles (regiones)
*
* H0: varianza del error es constante (homocedasticidad) entre regiones
* Si p<0.05 -> hay heteroscedasticidad -> usar SE robustos (cluster)
*------------------------------------------------------------*
* IMPORTANTE: xttest3 requiere FE estimado inmediatamente antes
* (si acabas de correr FE_tw, xttest3 se aplica sobre ese modelo)
capture which xttest3
if _rc {
    ssc install xttest3, replace
}
xttest3

*------------------------------------------------------------*
* 6.4) CORRELACIÓN SERIAL (AR(1)) en panel (Wooldridge)
*
* Prueba recomendada:
* - xtserial (Drukker/Wooldridge)
*
* H0: no autocorrelación de primer orden en los errores (AR(1)=0)
* Si p<0.05 -> hay autocorrelación -> SE cluster y/o corrección adicional
*------------------------------------------------------------*
capture which xtserial
if _rc {
    ssc install xtserial, replace
}
xtserial ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP

*------------------------------------------------------------*
* 6.5) DEPENDENCIA TRANSVERSAL (correlación contemporánea)
*
* Prueba recomendada:
* - Pesaran CD (xtcsd, pesaran abs)
*
* H0: independencia transversal (errores no correlacionados entre regiones)
* Si p<0.05 -> existe dependencia transversal
* Implicación: puede ser preferible reportar SE robustos a dependencia
* transversal (p.ej., Driscoll-Kraay) además de cluster.
*------------------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP i.Año, fe

capture which xtcsd
if _rc {
    ssc install xtcsd, replace
}
* xtcsd se ejecuta después de xtreg (FE) en memoria:
xtcsd, pesaran abs

*------------------------------------------------------------*
* 6.6) MODELO FINAL RECOMENDADO (inferencia robusta)
*
* Opción A (mínimo estándar y muy defendible):
* - Errores estándar cluster por región (robustos a heteroscedasticidad
*   y autocorrelación dentro de región).
*
* Nota:
* - Si testparm indicó efectos de tiempo, se reporta con i.Año.
*------------------------------------------------------------*
xtreg ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP i.Año, fe vce(cluster Region)
estimates store FE_final_cluster

*------------------------------------------------------------*
* 6.7) ROBUSTEZ ADICIONAL (si hay dependencia transversal)
*
* Si Pesaran CD rechaza H0 (p<0.05), es recomendable reportar también
* una estimación con errores estándar Driscoll–Kraay (robustos a:
* heteroscedasticidad, autocorrelación y dependencia transversal).
*
* Requiere comando xtscc.
*------------------------------------------------------------*
capture which xtscc
if _rc {
    ssc install xtscc, replace
}
* Driscoll–Kraay con efectos fijos y dummies de año:
xtscc ET CIN lnIEPperc lnIE lnNPROJ lnDUR lnCV lnDP i.Año, fe
estimates store FE_final_DK

*------------------------------------------------------------*
* 6.8) (Opcional) Tabla breve de comparación (solo para reporte interno)
*
* Sugerencia:
* - Reportar en tesis el modelo final (cluster) y, si aplica, la robustez DK.
*------------------------------------------------------------*
estimates table FE_base FE_tw FE_final_cluster FE_final_DK, star stats(N r2 r2_a)

****************************************************************************************
* FIN DEL APARTADO 6
*
* Redacción sugerida para tesis (idea central):
* - Se validó la necesidad de efectos temporales.
* - Se diagnosticó heteroscedasticidad, autocorrelación y dependencia transversal.
* - La inferencia se basó en errores estándar robustos (cluster por región)
*   y se verificó robustez con Driscoll–Kraay cuando correspondía.
****************************************************************************************/


