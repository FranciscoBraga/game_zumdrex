extends RefCounted
# Fases do jogo. A saída é sempre a linha do topo do tabuleiro.
#
# Legenda do mapa:
#   .  chão            M  mesa       X  entulho      W  parede     d  porta trancada
#   P  Sobrevivente    D  Cachorro   B  Bebê Chorão
#   Z  Zumbi Comum     R  Corredor   T  Tanque       K  Saltador
#   N  Peão Podre      C  Rastejante G  Trotador     U  Brutamontes
#   com super poderes (atacam de longe):
#   S  Cuspidor        O  Policial   J  Necromante   Q  Rainha Zumbi
#   Y  Gritador        F  Soldado    A  Arqueiro     I  Inchado
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
	{
		"name": "Fila de Peões",
		"intro": "Peões Podres só descem e mordem na DIAGONAL da frente, como o peão do xadrez: parado bem na frente deles você está seguro! Se um peão chegar ao fim, vira Tanque. As manchas escuras são Rastejantes escondidos: acordam quando você chega a 2 casas e andam na diagonal.",
		"backpack": 4, "weapon": "pistol", "ammo": 4,
		"map": [
			".......",
			"N.N.N.N",
			"...M...",
			".C...C.",
			"..X....",
			"....a..",
			"...P...",
		],
	},
	{
		"name": "Investida",
		"intro": "O Trotador anda até 2 casas em linha reta. O Brutamontes corre até 3 casas, EMPURRA você quando morde e fica tonto depois de uma investida longa — aproveite para atirar! Use móveis para bloquear o caminho deles.",
		"backpack": 4, "weapon": "pistol", "ammo": 4,
		"map": [
			"........",
			"..U.....",
			".W....W.",
			"....G...",
			".M....M.",
			"..h..G..",
			"........",
			"P..s....",
		],
	},
	{
		"name": "Delegacia",
		"intro": "Agora eles atacam DE LONGE! Passe o mouse num zumbi: as casas roxas mostram até onde ele acerta. Móveis, paredes e outros zumbis bloqueiam os tiros. O Cuspidor deixa ácido no chão, o Policial larga munição e o Soldado atira atravessando, mas precisa recarregar.",
		"backpack": 4, "weapon": "pistol", "ammo": 6,
		"map": [
			"........",
			"..F.....",
			".XX..XX.",
			"....S...",
			"O.......",
			".M..M..M",
			"..h..a..",
			"P...r...",
		],
	},
	{
		"name": "Cemitério",
		"intro": "O Necromante levanta os zumbis abatidos perto dele: derrube-o primeiro! O Arqueiro foge quando você chega perto. O Inchado explode e fere quem estiver em volta, até zumbis. Pegue o arco!",
		"backpack": 4, "weapon": "pistol", "ammo": 5,
		"map": [
			"........",
			"..A..J..",
			".X....X.",
			"...Z....",
			".....I..",
			".M....M.",
			"........",
			".h....a.",
			"P..b....",
		],
	},
	{
		"name": "A Rainha",
		"intro": "Chefe final! A Rainha Zumbi anda como a dama e grita de longe. Zumbis perto dela agem DUAS vezes. O Gritador fere tudo em volta e chama os outros. Fuja pela linha de cima ou derrube a Rainha!",
		"backpack": 5, "weapon": "pistol", "ammo": 8,
		"map": [
			".........",
			"....Q....",
			".W.....W.",
			"..Z...Z..",
			".........",
			"...Y.....",
			".M.....M.",
			"....h..a.",
			".........",
			"P...s...r",
		],
	},
]
