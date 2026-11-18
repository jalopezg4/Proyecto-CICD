// Reporte Allure de las E2E (npm run report:allure, y en el CI/CD como artefacto del run).
// Un solo HTML: se descarga del run, se abre con doble clic y trae todo adentro (pasos
// Dado/Cuando/Entonces, y si algo falla, pantallazo, video y trace).
import { defineConfig } from "allure";

export default defineConfig({
  name: "Gastico · E2E",
  output: "./allure-report",
  plugins: {
    awesome: {
      options: {
        singleFile: true,
        reportLanguage: "es",
        theme: "auto",
        groupBy: ["parentSuite", "suite"],
      },
    },
  },
});
