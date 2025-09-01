<div class="page">
	<div class="mb-3">
	  <h5 class="card-title mb-2"><i class="fa-solid fa-cash-register"></i> Estatus de cajas (hoy)</h5>
	  <div class="cajas-grid">
		<!-- Card 1 -->
		<div class="caja-card">
		  <div class="d-flex justify-content-between align-items-center mb-1">
			<div class="title">Sucursal 1</div>
			<span class="chip open">Abierta</span>
		  </div>
		  <div class="small text-muted mb-2">Terminal 101 • Cajero: jperez</div>
		  <div class="d-flex justify-content-between">
			<div class="small">Apertura: <strong>09:05</strong></div>
			<div class="small">Vendido: <strong>$3,250.50</strong></div>
		  </div>
		  <div class="mt-2 text-end">
			<a class="btn btn-sm btn-outline-primary" href="caja/cortes">Ver detalle</a>
		  </div>
		</div>

		<!-- Card 2 -->
		<div class="caja-card">
		  <div class="d-flex justify-content-between align-items-center mb-1">
			<div class="title">Sucursal 2</div>
			<span class="chip closed">Cerrada</span>
		  </div>
		  <div class="small text-muted mb-2">Terminal 102 • Cajero: -</div>
		  <div class="d-flex justify-content-between">
			<div class="small">Apertura: <strong>—</strong></div>
			<div class="small">Vendido: <strong>—</strong></div>
		  </div>
		  <div class="mt-2 text-end">
			<a class="btn btn-sm btn-outline-secondary disabled" href="#">Sin turno</a>
		  </div>
		</div>

		<!-- Card 3 -->
		<div class="caja-card">
		  <div class="d-flex justify-content-between align-items-center mb-1">
			<div class="title">Sucursal 3</div>
			<span class="chip open">Abierta</span>
		  </div>
		  <div class="small text-muted mb-2">Terminal 201 • Cajero: mlara</div>
		  <div class="d-flex justify-content-between">
			<div class="small">Apertura: <strong>09:30</strong></div>
			<div class="small">Vendido: <strong>$1,980.00</strong></div>
		  </div>
		  <div class="mt-2 text-end">
			<a class="btn btn-sm btn-outline-primary" href="caja/cortes">Ver detalle</a>
		  </div>
		</div>
	  </div>
	</div>

	<ul class="nav nav-pills mb-3" role="tablist">
	  <li class="nav-item"><button class="nav-link active" data-bs-toggle="pill" data-bs-target="#tabApertura">Apertura</button></li>
	  <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#tabPrecorte">Precorte</button></li>
	  <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#tabCorte">Corte</button></li>
	  <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#tabPostcorte">Postcorte</button></li>
	</ul>

	<div class="tab-content">
	  <div class="tab-pane fade show active" id="tabApertura">
		<form class="row g-2">
		  <div class="col-md-3">
			<label class="form-label">Sucursal</label>
			<input class="form-control" placeholder="PRINCIPAL">
		  </div>
		  <div class="col-md-3">
			<label class="form-label">Terminal</label>
			<input type="number" class="form-control" placeholder="101">
		  </div>
		  <div class="col-md-3">
			<label class="form-label">Cajero (user_id)</label>
			<input type="number" class="form-control" placeholder="1">
		  </div>
		  <div class="col-md-3">
			<label class="form-label">Fondo inicial</label>
			<input type="number" step="0.01" class="form-control" value="0">
		  </div>
		  <div class="col-12 text-end">
			<button class="btn btn-success" type="button">Abrir turno</button>
		  </div>
		</form>
	  </div>

	  <div class="tab-pane fade" id="tabPrecorte">
		<div class="alert alert-info">Aquí se mostrará el snapshot de ventas por método de pago (solo maquetación).</div>
		<table class="table table-sm align-middle">
		  <thead><tr><th>Método</th><th class="text-end">Sistema</th></tr></thead>
		  <tbody>
			<tr><td>Efectivo</td><td class="text-end">$ 0.00</td></tr>
			<tr><td>Débito</td><td class="text-end">$ 0.00</td></tr>
			<tr><td>Crédito</td><td class="text-end">$ 0.00</td></tr>
		  </tbody>
		</table>
	  </div>

	  <div class="tab-pane fade" id="tabCorte">
		<div class="alert alert-warning">Ingresa conteos físicos por método de pago (solo maquetación).</div>
		<table class="table table-sm align-middle">
		  <thead><tr><th>Método</th><th class="text-end">Sistema</th><th class="text-end">Contado</th><th class="text-end">Diferencia</th></tr></thead>
		  <tbody>
			<tr><td>Efectivo</td><td class="text-end">$ 0.00</td><td class="text-end"><input class="form-control form-control-sm text-end" type="number" step="0.01" value="0"></td><td class="text-end">$ 0.00</td></tr>
			<tr><td>Débito</td><td class="text-end">$ 0.00</td><td class="text-end"><input class="form-control form-control-sm text-end" type="number" step="0.01" value="0"></td><td class="text-end">$ 0.00</td></tr>
			<tr><td>Crédito</td><td class="text-end">$ 0.00</td><td class="text-end"><input class="form-control form-control-sm text-end" type="number" step="0.01" value="0"></td><td class="text-end">$ 0.00</td></tr>
		  </tbody>
		</table>
		<div class="text-end"><button class="btn btn-danger" type="button">Cerrar turno</button></div>
	  </div>

	  <div class="tab-pane fade" id="tabPostcorte">
		<div class="alert alert-secondary">Registra depósitos y comisiones (solo maquetación).</div>
		<table class="table table-sm align-middle">
		  <thead><tr><th>Ref banco</th><th>Método</th><th class="text-end">Monto</th><th class="text-end">Comisión</th><th>Notas</th></tr></thead>
		  <tbody>
			<tr>
			  <td><input class="form-control form-control-sm"></td>
			  <td>
				<select class="form-select form-select-sm">
				  <option>CASH</option><option>DEBIT</option><option>CREDIT</option>
				</select>
			  </td>
			  <td><input class="form-control form-control-sm text-end" type="number" step="0.01"></td>
			  <td><input class="form-control form-control-sm text-end" type="number" step="0.01" value="0"></td>
			  <td><input class="form-control form-control-sm"></td>
			</tr>
		  </tbody>
		</table>
		<div class="text-end"><button class="btn btn-warning" type="button">Registrar postcorte</button></div>
	  </div>
	</div>
	<h2 class="h5 mt-4">Turnos abiertos</h2>
	<table class="table table-sm">
	  <thead><tr><th>Shift</th><th>Sucursal</th><th>Terminal</th><th>Cajero</th><th>Abierto</th><th class="text-end">Acciones</th></tr></thead>
	  <tbody>
		<tr><td>#123</td><td>PRINCIPAL</td><td>101</td><td>jperez</td><td>09:05</td>
		<td class="text-end"><button class="btn btn-sm btn-outline-primary">Seleccionar</button></td></tr>
	  </tbody>
	</table>

	<h2 class="h6 mt-4">Conteo rápido</h2>
	<div class="row g-2">
	  <div class="col-md-6">
		<div class="card border-0 shadow-sm">
		  <div class="card-header bg-white"><strong>Efectivo (denominaciones)</strong></div>
		  <div class="card-body">
			<table class="table table-sm mb-0">
			  <thead><tr><th>Denom</th><th class="text-end">Cantidad</th><th class="text-end">Total</th></tr></thead>
			  <tbody>
				<tr><td>$500</td><td class="text-end"><input class="form-control form-control-sm text-end" value="0"></td><td class="text-end">$ 0.00</td></tr>
				<tr><td>$200</td><td class="text-end"><input class="form-control form-control-sm text-end" value="0"></td><td class="text-end">$ 0.00</td></tr>
				<tr><td>$100</td><td class="text-end"><input class="form-control form-control-sm text-end" value="0"></td><td class="text-end">$ 0.00</td></tr>
				<tr><td colspan="2" class="text-end"><strong>Total efectivo</strong></td><td class="text-end">$ 0.00</td></tr>
			  </tbody>
			</table>
		  </div>
		</div>
	  </div>
	  <div class="col-md-6">
		<div class="card border-0 shadow-sm">
		  <div class="card-header bg-white"><strong>Otros métodos</strong></div>
		  <div class="card-body">
			<table class="table table-sm mb-0">
			  <thead><tr><th>Método</th><th class="text-end">Sistema</th><th class="text-end">Contado</th></tr></thead>
			  <tbody>
				<tr><td>Débito</td><td class="text-end">$ 0.00</td><td class="text-end"><input class="form-control form-control-sm text-end" value="0"></td></tr>
				<tr><td>Crédito</td><td class="text-end">$ 0.00</td><td class="text-end"><input class="form-control form-control-sm text-end" value="0"></td></tr>
			  </tbody>
			</table>
		  </div>
		</div>
	  </div>
	</div>

	<h2 class="h6 mt-4">Tickets abiertos</h2>
	<table class="table table-sm">
	  <thead><tr><th>Ticket</th><th>Hora</th><th>Importe</th><th class="text-end">Acciones</th></tr></thead>
	  <tbody>
		<tr><td>TK-998</td><td>10:12</td><td>$ 85.00</td><td class="text-end">
		  <button class="btn btn-sm btn-outline-success">Cerrar</button>
		  <button class="btn btn-sm btn-outline-danger">Cancelar</button>
		</td></tr>
	  </tbody>
	</table>

	<h2 class="h6 mt-4">Descuentos</h2>
	<table class="table table-sm">
	  <thead><tr><th>Folio</th><th>Usuario</th><th>Motivo</th><th>%</th><th class="text-end">Acciones</th></tr></thead>
	  <tbody>
		<tr><td>TK-1001</td><td>abarista</td><td>Cliente frecuente</td><td>10</td>
		  <td class="text-end"><button class="btn btn-sm btn-outline-primary">Autorizar</button></td></tr>
	  </tbody>
	</table>
	<h2 class="h5 mt-4">Conciliación y depósito</h2>
	<div class="row g-2">
	  <div class="col-lg-6">
		<div class="card-vo p-3">
		  <h5 class="card-title"><i class="fa-solid fa-scale-balanced"></i> Diferencias</h5>
		  <table class="table table-sm mb-0">
			<thead><tr><th>Método</th><th class="text-end">Sistema</th><th class="text-end">Contado</th><th class="text-end">Dif.</th></tr></thead>
			<tbody>
			  <tr><td>Efectivo</td><td class="text-end">$ 2,350.00</td><td class="text-end">$ 2,345.00</td><td class="text-end text-danger">-5.00</td></tr>
			  <tr><td>Crédito</td><td class="text-end">$ 1,280.00</td><td class="text-end">$ 1,280.00</td><td class="text-end">0.00</td></tr>
			  <tr><td>Débito</td><td class="text-end">$ 840.00</td><td class="text-end">$ 840.00</td><td class="text-end">0.00</td></tr>
			</tbody>
		  </table>
		</div>
	  </div>
	  <div class="col-lg-6">
		<div class="card-vo p-3">
		  <h5 class="card-title"><i class="fa-solid fa-piggy-bank"></i> Depósito</h5>
		  <div class="row g-2">
			<div class="col-6"><input class="form-control form-control-sm" placeholder="Banco"></div>
			<div class="col-6"><input class="form-control form-control-sm" placeholder="Referencia"></div>
			<div class="col-12"><textarea class="form-control form-control-sm" rows="2" placeholder="Notas"></textarea></div>
		  </div>
		  <div class="mt-2 d-flex gap-2 justify-content-end">
			<button class="btn btn-sm btn-outline-secondary"><i class="fa-regular fa-file-pdf"></i> PDF</button>
			<button class="btn btn-sm btn-outline-secondary"><i class="fa-regular fa-file-excel"></i> Excel</button>
			<button class="btn btn-sm btn-primary"><i class="fa-solid fa-floppy-disk"></i> Guardar</button>
		  </div>
		</div>
	  </div>
	</div>

</div>