# Network Settings

Ventana propia de Pedro accesible mediante «Network Settings…» en los menús de red y desde el botón de ajustes del control center. Reutiliza `window/frame.qml`: controles de ventana, movimiento y resize existentes, Liquid frosted y superficie oscura de transparencia moderada. La ventana existente se vuelve a presentar al abrir ajustes, conservando su navegación.

## Popup de acceso rápido

El icono de red de la barra superior abre un popup, no la ventana Settings. Según la conexión detectada, muestra Wi-Fi o Ethernet. Ethernet usa un panel de cristal de 316 × 354, cabecera con icono circular y estado, tarjeta agrupada de nombre/IP/velocidad y una fila redondeada de ajustes, separador bajo la cabecera y tinte oscuro propio. El nombre y estado son reales; IP y velocidad muestran «—» hasta integrar métricas PAPI. La cabecera es informativa, sin flecha ni navegación; ajustes abre la ventana existente. El acceso a Diagnostics permanece en la ventana Settings. Wi-Fi conserva su interruptor, búsqueda y lista de redes. Ambos muestran siempre al pie el acceso a Network Settings, separado por una línea sutil. La configuración extensa permanece en la ventana Settings. Conectar a una red Wi-Fi desde la lista todavía requiere integrar activación y credenciales mediante PAPI/NetworkManager.

## Navegación

```text
Network
├── Wi-Fi → Current / Available / Known Networks → Details
├── Ethernet → Estado / Nombre / Velocidad / IP → Advanced
├── VPN → Add / Saved Connections
├── Proxy → Off / Automatic (PAC) / Manual (HTTP, HTTPS, SOCKS)
└── Advanced → IPv4 / IPv6, DNS, Routes, Known Networks,
               Sharing, Airplane Mode, Hardware, Diagnostics
    └── Diagnostics → Resumen → View Details
```

El lateral permite navegar directamente entre las siete vistas. Los formularios y listas desplazan verticalmente; las opciones técnicas no ocupan el resumen. Los componentes `network/row.qml` y `network/field.qml` comparten presentación y controles entre secciones. `network/view.qml` contiene el estado local de navegación y borradores de diseño, sin llamadas Linux de bajo nivel. Las etiquetas se resuelven con claves `settings.network.*` en los catálogos Qt inglés/español.

## Integración disponible

PAPI obtiene la conexión principal de NetworkManager mediante D-Bus asíncrono y eventos; distingue Wi-Fi, Ethernet, otros tipos y ausencia de conexión. Wi-Fi muestra la red actual, redes detectadas y estado de protección, y permite cambiar el radio únicamente cuando hay hardware disponible. Ethernet presenta estado y nombre reales de la conexión.

## Propuesta visual y límites

Los campos de velocidad/IP/configuración automática de Ethernet aún no tienen datos integrados. No se muestran valores de ejemplo como datos reales. Known Networks, Auto-connect, Metered, Forget, VPN, Proxy y opciones avanzadas necesitan backends de lectura/escritura. Los formularios permiten explorar el diseño; los botones Apply y las acciones no conectadas están desactivados y se indica que son vista previa. No guardan ni cambian perfiles del sistema.

Diagnostics muestra solamente el estado de conexión conocido. Gateway, Internet y DNS permanecen «Not checked»; ejecutar esas pruebas y mostrar detalles reales queda pendiente. No se inventan resultados positivos ni logs. La configuración futura debe delegarse a NetworkManager y servicios existentes mediante PAPI, usando la misma arquitectura en Ubuntu development y producción.
