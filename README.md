🦁 Slim Brave Optimizer Pro

<img width="1034" height="894" alt="image" src="https://github.com/user-attachments/assets/df3dcf83-fa38-4e67-a29c-5143b03b65f8" />

Slim Brave Optimizer Pro es una herramienta avanzada con interfaz gráfica nativa (WPF/XAML) escrita puramente en PowerShell. Su objetivo es optimizar, limpiar y blindar la privacidad del navegador Brave en Windows utilizando las Políticas de Empresa (Enterprise Policies) oficiales de Chromium, sin necesidad de compilar código ni instalar software de terceros.

✨ Características Principales
🎨 Interfaz UI/UX Moderna: Construida en XAML dinámico, con soporte total para el Modo Claro y Modo Oscuro de Windows 11, y coloreado automático de la barra de título nativa.

🛡️ Control Total de Privacidad: Bloquea la telemetría oculta, el rastreo de URLs, métricas de Chromium y fugas de IP por WebRTC.

🚀 Rendimiento Extremo: Desactiva extensiones en segundo plano, sugerencias de búsqueda que consumen recursos, herramientas de criptomonedas (Rewards/Wallet) y bloatware visual.

🧹 Limpieza Integrada: Motor de purga de caché con un solo clic para liberar espacio en disco al instante.

⚡ Arquitectura Dinámica: Las 35 reglas de políticas se generan y mapean dinámicamente, asegurando que el código sea fácil de mantener y escalar.

🎛️ Perfiles de Optimización (1-Click)
La herramienta incluye 5 perfiles preconfigurados para adaptarse a cualquier usuario:

Por Defecto: Restaura Brave a su configuración de fábrica.

Estándar: Aplica bloqueos básicos de telemetría y publicidad, ideal para uso diario.

Optimizado (Recomendado): El balance perfecto. Desactiva criptomonedas, telemetría y bloatware, manteniendo las funciones útiles del navegador intactas.

Privacidad Máxima: Fuerza bloqueos agresivos, modo incógnito estricto y previene todo tipo de rastreo e historial.

Rendimiento Puro: Apaga cualquier subproceso secundario (F12, traductor, corrector ortográfico) para máxima velocidad en equipos de bajos recursos.

⚙️ Requisitos y Uso
Sistema Operativo: Windows 10 / Windows 11.

No requiere instalación, solo descargar y ejecutar.

Instrucciones:

Descarga el archivo SlimBraveOptimizerPro.ps1.

Haz clic derecho sobre el archivo y selecciona "Ejecutar con PowerShell".

Nota: El script solicitará permisos de Administrador automáticamente, ya que es necesario para modificar las políticas en el registro de Windows (HKLM:\SOFTWARE\Policies\).

🤝 Créditos y Agradecimientos
Este proyecto evolucionó a partir del excelente código base de ltx0101/SlimBrave.

Todo el mérito de la investigación original de las llaves de registro, la estructura de políticas empresariales de Brave y la lógica inicial en consola pertenece a su autor original. Esta versión "Pro" toma ese robusto motor de políticas y lo envuelve en una interfaz gráfica XAML interactiva, uniendo la potencia del script original con una experiencia visual moderna.

Puedes ejecutarlo usando este codigo en powershell (o bajar el .ps1)
```plaintext Invoke-RestMethod -Uri "https://raw.githubusercontent.com/DanserAlvis/Slim-Brave-Optimizer-Pro/refs/heads/main/SlimBraveOptimizerPro.ps1" | Invoke-Expression ```

⚠️ Aviso Legal
Este script modifica parámetros del registro de Windows (HKEY_LOCAL_MACHINE). Aunque las modificaciones están basadas en las políticas oficiales documentadas por Brave/Chromium, el uso de esta herramienta es bajo tu propio riesgo. Se recomienda revisar el código fuente antes de su ejecución.
