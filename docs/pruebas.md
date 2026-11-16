# Matriz de Pruebas y Evidencias Técnicas

Esta matriz vincula los Requisitos Funcionales (**RF**), Casos de Uso, Endpoints REST, Pruebas Automatizadas (**PA**) y los Criterios de Aceptación (**CA**) conforme a la especificación oficial del proyecto integrador.

---

## 1. Matriz RF → Caso de Uso → Endpoint → Prueba → Resultado

| ID Requisito | Caso de Uso | Endpoint REST | Prueba Asociada | Criterio de Aceptación (CA) | Resultado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RF-01** (Catálogo y detalle) | `GetProducts`, `GetProductDetail` | `GET /api/products`<br>`GET /api/products/{id}` | `PA-02` (Unitarias móvil Application)<br>`test/get_products_test.dart` | **CA-01:** Consulta catálogo y detalle de productos reales desde Odoo; datos faltantes no provocan caída. | **SUPERADO** (100%) |
| **RF-02** (Categorías y filtro) | `GetCategories`, `GetProducts(categoryId)` | `GET /api/categories`<br>`GET /api/products?categoryId=X` | `PA-02` (Filtrado por categoría en móvil) | **CA-02:** Seleccionar categoría muestra únicamente productos asociados; si no existen, informa estado vacío. | **SUPERADO** (100%) |
| **RF-03** (Carrito móvil) | `AddProductToCart`, `SetCartQuantity`, `RemoveProductFromCart`, `ClearCart` | N/A (Regla de Dominio Móvil) | `PA-01` (Unitarias móvil carrito)<br>`test/cart_test.dart` | **CA-03:** Cantidades estrictamente positivas (>0), subtotal orientativo en tiempo real, eliminación de artículos. | **SUPERADO** (100%) |
| **RF-04** (Clientes / Auth) | `RegisterCustomer`, `LoginCustomer` | `POST /api/auth/register`<br>`POST /api/auth/login` | `PA-04` (Unitarias .NET / autorización) | **CA-04:** Credenciales inválidas deniegan acceso; cliente autenticado opera con JWT sin exponer secretos de Odoo. | **SUPERADO** (100%) |
| **RF-05** (Confirmar pedido) | `CreateOrder` | `POST /api/orders` | `PA-03` (Unitarias .NET / Application)<br>`backend/ECommerce.Tests/CreateOrderTests.cs` | **CA-05:** Valida líneas de pedido en servidor, rechaza pedidos vacíos o cantidades `<=0`, registra orden en Odoo. | **SUPERADO** (100%) |
| **RF-06** (Historial propio) | `GetCustomerOrders`, `GetCustomerOrderDetail` | `GET /api/orders`<br>`GET /api/orders/{id}` | `PA-04` (Unitarias .NET / autorización)<br>`backend/ECommerce.Tests/OrderAuthorizationTests.cs` | **CA-06:** El cliente ve sus pedidos y estados; solicitud de pedido perteneciente a otro cliente devuelve 403 Forbidden. | **SUPERADO** (100%) |
| **RF-07** (Administración Odoo) | N/A (Interfaz Web Odoo) | `POST /json/2/product.product/search_read` | `PA-05` / `PA-06` (Integración Odoo) | **CA-07:** Modificaciones en catálogo de Odoo se reflejan dinámicamente en consultas de la app. | **SUPERADO** (100%) |

---

## 2. Comandos de Ejecución de Pruebas Automatizadas

### A. Pruebas Unitarias del Backend .NET (PA-03 y PA-04)
Desde la raíz del proyecto o desde la carpeta `backend`:
```powershell
dotnet test backend/ECommerce.Tests
```
* **Resultado verificado:** 9 pruebas ejecutadas, **9 superadas**, 0 errores.
  * Validación de pedido vacío.
  * Rechazo de cantidades `<= 0`.
  * Rechazo de productos inexistentes en catálogo.
  * Comprobación de cálculo con precios de Odoo.
  * Rechazo de acceso a pedidos de otro cliente con identidad simulada (403 Forbidden).

### B. Pruebas Unitarias de la Aplicación Móvil en Flutter (PA-01 y PA-02)
Desde la carpeta `mobile`:
```powershell
flutter test
```
* **Resultado verificado:** 10 pruebas ejecutadas, **10 superadas**, 0 errores.
  * Operaciones de carrito: agregar, acumular, modificar y eliminar artículos.
  * Validación de cantidades estrictamente positivas en carrito (excepciones ante `<= 0`).
  * Consulta de productos con Fake Repository sin red.
  * Filtrado de productos por categoría.
  * Manejo controlado de excepciones de red.
