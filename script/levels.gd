extends RefCounted
# Fases do jogo. A saída é sempre a linha do topo do tabuleiro.
#
# Legenda do mapa:
#   .  chão            M  mesa       X  entulho      W  parede     d  porta trancada
#   P  Sobrevivente    D  Cachorro   B  Bebê Chorão
#   Z  Zumbi Comum     R  Corredor   T  Tanque       K  Saltador
#   k  chave           h  kit médico a  munição      s  escopeta   r  rifle
#   b  arco e flecha   f  flecha solta (+1 munição)

const LEVELS := [
	{
		"name": "Primeiros Passos",
		"intro": "Leve o Sobrevivente até a linha de cima (SAÍDA). Ele anda 1 casa em qualquer direção, como o rei do xadrez. O zumbi só anda reto.",
		"backpack": 3, "weapon": "pistol", "ammo": 2,
		"map": [
			"Z...",
			".M..",
			"....",
			"...P",
		],
	},
	{
		"name": "Rua Bloqueada",
		"intro": "A passagem está trancada. Pegue a chave para abrir a porta. Atirar gasta munição e a rodada. Pegue o ARCO: ele acerta até 4 casas e a flecha cai no chão; passe por cima dela para recuperar.",
		"backpack": 3, "weapon": "pistol", "ammo": 3,
		"map": [
			"..Z...",
			"WWWdWW",
			"..a...",
			".Z..M.",
			"Mb..k.",
			"P.....",
		],
	},
	{
		"name": "O Melhor Amigo",
		"intro": "O Cachorro se move em L, como o cavalo, e pula obstáculos. Clique nele para controlá-lo. Se for mordido, vira zumbi! O Corredor anda em qualquer direção.",
		"backpack": 4, "weapon": "pistol", "ammo": 3,
		"map": [
			".......",
			"..R....",
			"W..M..W",
			"..Z..h.",
			".M...W.",
			"...s...",
			"P.....D",
		],
	},
	{
		"name": "Bebê Chorão",
		"intro": "O choro do bebê atrai TODOS os zumbis. Encoste no bebê para pegá-lo no colo e leve-o até a saída. Se ele for pego, a missão falha. O Tanque é forte mas lento; o Saltador pula em L e descansa uma rodada após cada salto.",
		"backpack": 5, "weapon": "pistol", "ammo": 5,
		"map": [
			"........",
			"..T..K..",
			".WW..M..",
			"........",
			"..M.r.WB",
			".X....h.",
			"...a..X.",
			"Z....P..",
		],
	},
]
