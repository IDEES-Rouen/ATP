/***
* Name: MetaModel
* Author: mathieu
* Description: un mod�le g�n�rale de la diffusion des arch�oma�riaux dans le cadre du projet RIN ATP
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global{
	int nb_init_consommateur <- 10 parameter: true;
	int nb_init_intermediaire <- 8 parameter: true;
	int nb_init_prod <- 12 parameter: true;
	geometry shape <- square(2000);
	int stock_en_circulation <- 0;
	int prodTaux <- 50 parameter:true;
	int consumTaux <- 2000 parameter:true;
	int capaciteInter <- 30 parameter: true;
	int stock_max_prod <- 100 parameter: true;
	
	init {
		create Consommateur number: nb_init_consommateur;
		create Intermediaire number: nb_init_intermediaire;
		create Producteur number: nb_init_prod;
	}
	
	reflex affichage {
		write "-------------------------";
		stock_en_circulation <- 0;
		loop temp over: Intermediaire{
			stock_en_circulation<- stock_en_circulation + temp.stock;
		}
		loop temp over: Producteur{
			stock_en_circulation<- stock_en_circulation + temp.stock;
		}
	}
	
}

species Consommateur {
	int argent;
	int besoin <- rnd(consumTaux) update:rnd(consumTaux) ;
	int recupere <- 0 update: 0;
	
	reflex acheter {
		loop tempInt over: (Intermediaire where (each.stock>0)){
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		write "achat " + recupere;
	}
	
	//un carré de couleur dont la taille peut varier en foction d'un paramètre (le besoin, l'argent, etc ?)
	aspect base {
		draw square(10) color:#blue;
	}
}

species Intermediaire {
	//un disque dont la taille varie en fonction du stock
	int stock <- 0;
	int capacite <- rnd(capaciteInter); //capacite d'achat auprès des producteurs
	
	aspect base {
		if (stock>0){
			draw circle(stock) color:#green;
		} else {
			draw circle(1) color:#green;
		}
	}
}

species Producteur{
	int production <- rnd(prodTaux) update:rnd(prodTaux) ;//représente le nombre de marchandise produite en 1 cycle
	int stock <- 0 ;
	int stockMax <- rnd(stock_max_prod);
	
	reflex produit when: stock<stockMax{
		stock <- stock+production;
	}
	
	reflex vendre {
		if(stock>0){
			loop tempInt over: Intermediaire{
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
						}
					}
				}
			}
			write "vente " + stock;
		}
	}
	
	//un triangle dont a taille va dépenre du stock
	aspect base {
		if (stock>0){
			draw triangle(stock) color:#red;
		}else {
			draw triangle(1) color:#red;
		}
	}
}

species Marchandise{
	//un carré de taille fixe, la couleur pourrait varier en fonction du type de marchandise.
	aspect base {
		
	}
}

experiment name type: gui {

	
	// Define parameters here if necessary
	// parameter "My parameter" category: "My parameters" var: one_global_attribute;
	
	// Define attributes, actions, a init section and behaviors if necessary
	// init { }
	
	
	output {
	// Define inspectors, browsers and displays here
	
	// inspect one_or_several_agents;
	//
		display affichagePrincipal background: #lightgray { 
			species Consommateur aspect:base;
			species Intermediaire aspect:base;
			species Producteur aspect:base;
		}

		display chart /*refresh:every(10.0)*/  {
			chart "Stock en circulation" type: series {
				data "stock" value: stock_en_circulation color: #green;
			}
		}
	
	}
}