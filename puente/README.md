# Traducción puente

Thord82 tarda unos días en publicar su traducción tras cada parche del juego. Mientras tanto,
este repositorio puede publicar una **traducción puente**: la de Thord más los textos nuevos de
[StarStrings](https://github.com/MrKraken/StarStrings) (de la que parte Thord), para que no
aparezcan claves vacías ni textos sin traducir en la interfaz.

## Cómo la elige el script

`UpdateStarCitizenES.bat` busca en las releases de **este** repo una *pre-release* cuyo tag empiece
por `bridge-` y cuya descripción tenga una línea `BASE=<tag de la última release de Thord>`.

* Si `BASE` coincide con la última release de Thord → instala el puente.
* En cuanto Thord publica otra release (el tag ya no coincide) → el puente deja de aplicarse
  solo y se instala la de Thord. No hay que retirar nada a mano.
* Al ser pre-release no altera `releases/latest`, que usa la autoactualización del propio script.
* Si GitHub publica el `digest` sha256 del asset, el script lo comprueba antes de instalar.

## Generar un puente nuevo

1. Localiza los commits de StarStrings: el del build del que parte Thord (`--ss-old`) y el del
   build nuevo (`--ss-new`). Los mensajes son `Update for build sc-alpha-X.Y.Z_live_...`.
2. Descarga la última release de Thord (`Star_citizen_ES.zip`).
3. Ejecuta:

   ```
   python puente/build_puente.py --ss-old <sha> --ss-new <sha> \
       --thord-zip Star_citizen_ES.zip --traducciones puente/<version> --salida salida/
   ```

   Si hay claves nuevas o cambiadas sin traducir, escribe `salida/pendientes.json`
   (clave → inglés) y termina con código 2. Se traducen y se añaden a `nuevas.json` /
   `cambiadas.json`, y se repite. `cambiadas.json` puede contener el texto de Thord sin cambios
   cuando el cambio del inglés no afecta al español.
4. Publica `salida/Star_citizen_ES.zip` (el nombre debe ser exactamente ese) como **pre-release**:

   ```
   gh release create bridge-4.10.2 salida/Star_citizen_ES.zip --prerelease \
       --title "Traducción puente 4.10.2" \
       --notes $'Traducción de Thord (LIVE 4.10.1) + textos nuevos de StarStrings 4.10.2.\nBASE=v.4.10.10.00'
   ```

   `BASE` debe ser el tag **exacto** de la última release de Thord en ese momento.

## Contenido de `4.10.2/`

* `nuevas.json`: 521 claves nuevas de StarStrings 4.10.2, traducidas.
* `cambiadas.json`: 122 claves cuyo inglés cambió entre 4.10.1 y 4.10.2 (texto de Thord, parcheado
  donde hacía falta).
* `revision.csv`: las 598 cadenas que difieren de Thord, con inglés, español propuesto y el de Thord,
  para revisarlas cuando Thord publique su versión.

## Avisos

* Las traducciones nuevas son automáticas y no están revisadas por Thord.
* PTU y EPTU del puente son los de Thord sin cambios.
* StarStrings parte en varias líneas la descripción de `item_Desc_rrs_combat_heavy_backpack_01_04_01`
  (error de origen); el script descarta esas líneas sobrantes y conserva la descripción completa de Thord.
* Ni StarStrings ni Thord declaran licencia en sus repositorios: conviene avisarles.
