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
#   equipamentos (valem até o fim da fase; do mesmo tipo fica só o melhor):
#   1  boné branco (+10% vida)   2  boné verde (+20%)   3  boné preto (+30%)
#   v  fita vermelha (-10% de dano)   u  mochila nível 2 (+30% espaço)
#   y  mochila militar (+50% espaço)  o  anel do poder (anda até 2 casas)
#   t  tênis branco (anda até 3 casas)  m  mamadeira (acalma os bebês)

const LEVELS := [
	{
		"name": "Primeiros Passos",
		"intro": "Leve o Sobrevivente até a linha de cima (SAÍDA). Ele anda 1 casa em qualquer direção, como o rei do xadrez. O zumbi só anda reto. Pegue o BONÉ BRANCO: +10% de vida.",
		"backpack": 3, "weapon": "pistol", "ammo": 2,
		"map": [
			"Z...",
			".M..",
			"..1.",
			"...P",
		],
	},
	{
		"name": "Rua Bloqueada",
		"intro": "A passagem está trancada. Pegue a chave para abrir a porta. Atirar gasta munição e a rodada. Pegue o ARCO: ele acerta até 4 casas e a flecha cai no chão; passe por cima dela para recuperar. A FITA VERMELHA reduz em 10% o dano das mordidas.",
		"backpack": 3, "weapon": "pistol", "ammo": 3,
		"map": [
			"..Z...",
			"WWWdWW",
			"..a...",
			".Z..M.",
			"Mb..k.",
			"P....v",
		],
	},
	{
		"name": "O Melhor Amigo",
		"intro": "O Cachorro se move em L, como o cavalo, e pula obstáculos. Clique nele para controlá-lo. Ele tem 70 de vida: se chegar a 0, morre e vira zumbi! O Corredor anda em qualquer direção. A MOCHILA NÍVEL 2 tem 30% mais espaço.",
		"backpack": 4, "weapon": "pistol", "ammo": 3,
		"map": [
			".......",
			"..R....",
			"W..M..W",
			"..Z..h.",
			".M.u.W.",
			"...s...",
			"P.....D",
		],
	},
	{
		"name": "Bebê Chorão",
		"intro": "O choro do bebê atrai TODOS os zumbis. Encoste no bebê para pegá-lo no colo e leve-o até a saída. O bebê tem 50 de vida: se ele morrer, a missão falha. O Tanque é forte mas lento; o Saltador pula em L e descansa uma rodada após cada salto. A MAMADEIRA acalma o bebê por 3 rodadas.",
		"backpack": 5, "weapon": "pistol", "ammo": 5,
		"map": [
			"........",
			"..T..K..",
			".WW..M..",
			"........",
			"..M.r.WB",
			".X....h.",
			"m..a..X.",
			"Z....P..",
		],
	},
	{
		"name": "Fila de Peões",
		"intro": "Peões Podres só descem e mordem na DIAGONAL da frente, como o peão do xadrez: parado bem na frente deles você está seguro! Se um peão chegar ao fim, vira Tanque. As manchas escuras são Rastejantes escondidos: acordam quando você chega a 2 casas e andam na diagonal. O ANEL DO PODER deixa você andar até 2 casas.",
		"backpack": 4, "weapon": "pistol", "ammo": 4,
		"map": [
			".......",
			"N.N.N.N",
			"...M...",
			".C...C.",
			"..X..o.",
			"....a..",
			"...P...",
		],
	},
	{
		"name": "Investida",
		"intro": "O Trotador anda até 2 casas em linha reta. O Brutamontes corre até 3 casas, EMPURRA você quando morde e fica tonto depois de uma investida longa — aproveite para atirar! Use móveis para bloquear o caminho deles. BONÉ VERDE: +20% de vida.",
		"backpack": 4, "weapon": "pistol", "ammo": 4,
		"map": [
			"........",
			"..U.....",
			".W....W.",
			"....G...",
			".M....M.",
			"..h..G..",
			"......2.",
			"P..s....",
		],
	},
	{
		"name": "Delegacia",
		"intro": "Agora eles atacam DE LONGE! Passe o mouse num zumbi: as casas roxas mostram até onde ele acerta. Móveis, paredes e outros zumbis bloqueiam os tiros. O Cuspidor deixa ácido no chão, o Policial larga munição e o Soldado atira atravessando, mas precisa recarregar. A MOCHILA MILITAR tem 50% mais espaço.",
		"backpack": 4, "weapon": "pistol", "ammo": 6,
		"map": [
			"........",
			"..F.....",
			".XX..XX.",
			"....S...",
			"O.......",
			".M..M..M",
			"y.h..a..",
			"P...r...",
		],
	},
	{
		"name": "Cemitério",
		"intro": "O Necromante levanta os zumbis abatidos perto dele: derrube-o primeiro! O Arqueiro foge quando você chega perto. O Inchado explode e fere quem estiver em volta, até zumbis. Pegue o arco! O TÊNIS BRANCO deixa você andar até 3 casas.",
		"backpack": 4, "weapon": "pistol", "ammo": 5,
		"map": [
			"........",
			"..A..J..",
			".X....X.",
			"...Z....",
			".....I..",
			".M....M.",
			"...t....",
			".h....a.",
			"P..b....",
		],
	},
	{
		"name": "A Rainha",
		"intro": "Chefe final! A Rainha Zumbi anda como a dama e grita de longe. Zumbis perto dela agem DUAS vezes. O Gritador fere tudo em volta e chama os outros. Fuja pela linha de cima ou derrube a Rainha! BONÉ PRETO: +30% de vida.",
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
			"..3......",
			"P...s...r",
		],
	},
]
