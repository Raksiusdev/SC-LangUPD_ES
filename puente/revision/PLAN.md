# Plan de revisión de la traducción

Estado a 2026-10-11. Pensado para retomarse en sesiones nuevas (`/clear`) con poco contexto.

## Por qué por fases
* 90.946 cadenas ≈ 1,7 M tokens (EN) + 2,0 M (ES). Traducir todo desde cero costaría ~4–9 M tokens
  y perdería el trabajo de Thord; revisar todo, ~5 M. No compensa.
* Plan del usuario: Claude Pro. El consumo se dispara con contexto largo (>150k): **una sesión
  corta por lote**, el estado vive en este directorio, no en la conversación.

## Fases (de menos a más coste)
1. **Auditoría con scripts** (casi 0 tokens): candidatos sin traducir (ES == EN con aspecto de frase
   o de texto de interfaz), 342 cadenas sin tildes, 269 con marcadores `~mission()` / `%ls` distintos
   del inglés, mismo inglés con traducciones distintas, terminología inconsistente
   ("Tipo de objeto" / "Tipo de artículo"). Salida: `candidatos.json` (clave → motivo).
2. **Cadenas que reporte el usuario** (visto en el juego sin traducir): buscar la clave por el inglés
   en `puente/4.10.2/` / el `global.ini` de StarStrings y traducir.
3. **Revisar las 598 cadenas propias** (`puente/4.10.2/revision.csv`): ~30k tokens de lectura.
4. **Corregir lo detectado en la fase 1.**
5. **Revisión rodante opcional** por prioridad: menús/HUD → títulos de misiones → descripciones de
   objetos → cartas de misiones largas.

## Calibración (antes de fijar el ritmo)
1. Sesión nueva. Anotar `/usage` (semanal y sesión).
2. Procesar un lote piloto de 300 cadenas.
3. Anotar `/usage` otra vez. Ritmo = lo que quepa en ~3–5 % del semanal al día.
   Estimación sin medir: 300–500 cadenas/día revisando.

## Cómo guardar el progreso
* `puente/revision/lotes/<prefijo>.json`: cadenas de cada lote.
* `puente/revision/estado.json`: claves ya revisadas (para no repetir).
* `puente/revision/correcciones.json`: clave → español corregido. `build_puente.py` debe aplicarlas
  encima del texto de Thord **solo si el español de Thord no cambió** respecto al que se corrigió,
  para no pisar mejoras de Thord cuando publique una versión nueva.

## Pendiente de implementar
* Script de auditoría (fase 1).
* Soporte de `correcciones.json` en `build_puente.py`.

## Progreso
* **Lote 1** (2026-10-11): filas 0-299 de `puente/4.10.2/revision.csv`. Marcadores `~mission()`, etiquetas
  y cifras coinciden con el inglés en las 300. 10 correcciones en `correcciones.json`: «Robert» -> «Roberts
  Space Industries» (errata del inglés) y terminología de `item_Desc_cds_combat_superheavy_helmet_01_02_01,P`.
  Pendiente: filas 300-597 (lote 2) y que `build_puente.py` aplique `correcciones.json`.

## Calibración medida (lote 1, 2026-10-11)
* Antes: sesión 20 %, semanal 24 %. Después: sesión 25 %, semanal 25 %.
* 300 cadenas ≈ **+5 % de sesión (5 h) y +1 % del semanal**, incluyendo leer cartas largas completas.
* Con 3-5 % semanal al día caben ~900-1500 cadenas/día; el límite que aprieta es el de sesión (≈ 1 500 cadenas
  por ventana de 5 h). Las 598 propias se terminan con un lote más (~300) y el resto de la fase 1 con scripts.

* **Lote 2** (2026-10-11): filas 300-597 de `puente/4.10.2/revision.csv`. Marcadores `~mission()`, cifras y `
` coinciden (las diferencias de etiquetas/cifras son los bloques de DETALLES DE MISION añadidos por el puente). 5 correcciones en `correcciones.json`: «CORNERSTONE MAINTENANCE» -> «DEVELOPMENTS» (2), «Tauro» -> «Taurus», «Espere mas» -> «Espera más», terminología de `item_Desc_slaver_combat_medium_helmet_01_02_01,P`. Pendiente global: «DETALLES DE MISION» sin tilde (-> MISIÓN) en todas las cartas.
* Lote 2 (subagente, 2026-10-11): sesión 25→30 %, semanal 25→26 %. Mismo coste que el lote 1 (~5 % sesión, ~1 % semanal);
  el subagente figura con un 3 % del uso. El contexto de la sesión principal sigue pesando: hacer `/clear` entre lotes.

## Cierre del puente 4.10.2 (2026-10-13)
* Thord publicó `v.4.10.20.00` (LIVE 4.10.2) el 2026-10-12. El puente `bridge-4.10.2` quedó archivado (borrador).
* De las 598 cadenas propias, Thord tradujo 344 distinto, 247 idénticas y 7 en inglés (marcadores PH y nombres).
* Auditoría: ~1.720 cadenas siguen idénticas al inglés en Thord (nombres de producto, ropa, tutorial). Decisión: no se parchea.
* `correcciones.json` queda como histórico. Si hace falta otro puente, el flujo es el de `puente/README.md`.
