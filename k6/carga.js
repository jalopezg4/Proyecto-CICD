// Prueba de carga de Gastico con k6 (paso 6 del plan). Corre contra staging, nunca contra producción.
//
// Umbrales: /health p95 < 500 ms, página principal p95 < 1500 ms y errores < 1 %. Si no se
// cumplen, k6 termina con código distinto de 0 y el pipeline se pone en rojo.
// La página tiene más margen que el p95 < 500 ms del plan porque NiceGUI la arma completa en el
// servidor en cada visita: con 12-16 núcleos ya da ~0,5-1 s, y en Fargate hay menos CPU.
//
// SOLO LECTURA: no crea ni borra gastos. Pide la página principal (que a su vez consulta el
// resumen y la lista en el backend) y el /health del frontend (que consulta el /health del backend).
// El backend es privado, así que la carga le llega a través del frontend, como en la vida real.
//
// Uso:  k6 run -e BASE_URL=http://<alb-de-staging> k6/carga.js
import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = (__ENV.BASE_URL || "").replace(/\/$/, "");
if (!BASE_URL) {
  throw new Error("Falta BASE_URL: k6 run -e BASE_URL=http://<alb-de-staging> k6/carga.js");
}

export const options = {
  stages: [
    { duration: "15s", target: 10 }, // sube a 10 usuarios
    { duration: "30s", target: 10 }, // se mantiene
    { duration: "15s", target: 0 }, // baja
  ],
  thresholds: {
    // Un umbral por endpoint (no uno global que mezcle los dos). Se calibran con el número real
    // de staging en el paso 9.
    "http_req_duration{name:/health}": ["p(95)<500"], // API liviana
    "http_req_duration{name:pagina principal}": ["p(95)<1500"], // NiceGUI arma la página completa en el servidor
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
  },
};

export default function () {
  const pagina = http.get(`${BASE_URL}/`, { tags: { name: "pagina principal" } });
  check(pagina, {
    "la página responde 200": (r) => r.status === 200,
    "la página trae el formulario": (r) => r.body.includes("Registrar gasto"),
  });

  const salud = http.get(`${BASE_URL}/health`, { tags: { name: "/health" } });
  check(salud, {
    "/health responde 200": (r) => r.status === 200,
    "/health dice ok": (r) => r.json("status") === "ok",
  });

  sleep(1);
}
