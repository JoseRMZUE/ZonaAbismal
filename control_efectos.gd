extends Node
# Destello del golpe (Taller 5, Tarea B). Va como hijo de un enemigo: le pone
# efecto_objeto.gdshader ENCIMA de todas sus mallas y controla cuánto brilla.
#   mantener(color): brilla fijo mientras se llame (el aviso del Verdugo).
#   destello(color): un pulso que se apaga solo (cuando recibe un golpe).
# El apagado usa la misma curva exponencial del Taller 4 (SistemaEventos.decaer).

@export var color_aviso = Color(1.0, 0.15, 0.1)   # rojo: "va a pegar"
@export var color_golpe = Color(1.0, 1.0, 1.0)    # blanco: "le dieron"
@export var color_parry = Color(1.0, 0.85, 0.35)  # dorado: "le desviaron el golpe"
@export var k_apagado = 10.0                      # qué tan rápido se apaga

var material = null
var intensidad = 0.0


func _ready():
	material = ShaderMaterial.new()
	material.shader = load("res://efecto_objeto.gdshader")
	# owned = false: las mallas vienen de una escena instanciada (el modelo).
	for malla in get_parent().find_children("*", "MeshInstance3D", true, false):
		malla.material_overlay = material


func _process(delta):
	intensidad = SistemaEventos.decaer(intensidad, 0.0, k_apagado, delta)
	material.set_shader_parameter("intensidad", intensidad)


func mantener(color):
	material.set_shader_parameter("color_flash", color)
	intensidad = 1.0


func destello(color, fuerza = 1.0):
	material.set_shader_parameter("color_flash", color)
	intensidad = fuerza
