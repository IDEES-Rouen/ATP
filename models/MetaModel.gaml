/***
* Name: MetaModel
* Author: mathieu
* Description: un mod�le g�n�rale de la diffusion des arch�oma�riaux dans le cadre du projet RIN ATP
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global{
	int nb_init_consommateur <- 2 parameter: true;
	int nb_init_intermediaire <- 1 parameter: true; //correspond aux intermédiaires hors producteur et consommateur
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	int stock_en_circulation <- 0;
	int prodTaux <- 5 parameter:true;
	int prodTauxFixe <- 50 parameter:true;
	int consumTaux <- 5 parameter:true;
	int consumTauxFixe <- 50 parameter:true;
	int capaciteInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	
	init {
		do createConso(nb_init_consommateur);
		do createProd(nb_init_prod);
		do createInter(nb_init_intermediaire);
	}
	
	user_command "create conso"{ //à activer avec clic-droit->world->actions
		do createConso(1);
	}
	
	user_command "destroy conso"{
		do destroyConso;
	}
	
	user_command "create prod"{ //à activer avec clic-droit->world->actions
		do createProd(1);
	}
	
	user_command "destroy prod"{
		do destroyProd;
	}
	
	user_command "create inter"{ //à activer avec clic-droit->world->actions
		do createInter(1);
	}
	
	user_command "destroy inter"{
		do destroyInter;
	}
	
	action createConso(int nb_conso){
		create Consommateur number: nb_conso{
			//pour chaque consommateur, on lui crée un intermédiaire qui sera sa partie commerciale
			create Intermediaire number: 1{
				location <-myself.location;
				est_consommateur <- true;
				est_producteur <- false;
				capacite <- myself.besoin;
				stock <- myself.recupere;
				argent <- myself.argent;
				
				ask myself{
					mon_inter <- myself;
				}
			}
		}
	}
	
	action destroyConso{
		ask one_of(Consommateur){
			do die ;
		}
	}
	
	action createProd(int nb_prod){
		create Producteur number: nb_prod{
			//pour chaque producteur, on lui crée un intermédiaire qui sera sa partie commerciale
			create Intermediaire number: 1{
				location <-myself.location;
				est_consommateur <- false;
				est_producteur <- true;
				capacite <- myself.stockMax;
				stock <- myself.stock;
				
				ask myself{
					mon_inter <- myself;
				}
			}
		}
	}
	
	action destroyProd{
		ask one_of(Producteur){
			do die ;
		}
	}
	
	action createInter(int nb_inter){
		create Intermediaire number: nb_inter{
			est_producteur <- false;
			est_consommateur <- false;
			capacite <- rnd(capaciteInter);
		}
	}
	
	action destroyInter{
		ask one_of(Intermediaire where ((not(each.est_producteur)) and (not(each.est_consommateur)))){
			do die ;
		}
	}
	
	
	//TODO : afficher des polygones représentant les aires de présence de marchandise pour chaque producteur
	//TODO : faire la même chose mais pour chaque intermédiaire
	reflex affichage {
		write "-------------------------";
		stock_en_circulation <- 0;
		loop temp over: Intermediaire{
			stock_en_circulation<- stock_en_circulation + temp.stock;
		}
//		loop temp over: Producteur{
//			stock_en_circulation<- stock_en_circulation + temp.stock;
//		}
	}
	
}

species Consommateur {
	//TODO //diversifier en fonction des types et ajouter la variable d'argent.
	int argent;
	int besoin <- consumTauxFixe + rnd(consumTaux) update:consumTauxFixe + rnd(consumTaux) ; //dans le cade de la craie, le besoin serait fixe et représenterait le besoin total de la construction 
	int recupere <- 0 update: 0; //dans le cade de la craie, les matières récupérées ne seraient pas remise à zéro à chaque tour (cette remise à zéro symbolise la consommation)
	Intermediaire mon_inter; 
	
	bool est_construit; //utilisé sur les bâtiments pour montrer que le batiment n'a plus besoin de pierre.
	
	reflex updateInterStart{
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	//TODO ajouter l'argent dans le calcul
	//operateur sort pour ranger dans l'ordre de distance, ou alors on fait un calcul du prix pour chaque, puis on trie en fonction du prix, stocké dans un ou deux tableaux (arrays)
	reflex acheter { //on achète à tous les intermédiaires qui ne sont pas des consommateurs
//		do achat0;
		do achat1; //à remplacer en fonction de la méthode que l'on veut tester
//		do achat2;
	}
	
	action achat0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediaire where (not(each.est_consommateur))){
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(tempInt.est_producteur){
					write "achat prod " + recupTemp;
				} else {
					write "achat inter " + recupTemp;
				}
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	action achat1 { //Achat du maximum (en quantité) en fonction de la distance, sans pénalité rajoutée par les intermédiaires.
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self); //Le distance_to s'applique sur la topologie de l'agent appelant (chaque espèce possède une topology comme built-in attribute sur laquelle il évolue)
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(tempInt.est_producteur){
					write "achat prod " + recupTemp;
				} else {
					write "achat inter " + recupTemp;
				}
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	//TODO : préparer l'ajout d'un prix ou le calcul d'une autre distance (ou les deux)
	action achat2{ // Achat au plus loin
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(tempInt.est_producteur){
					write "achat prod " + recupTemp;
				} else {
					write "achat inter " + recupTemp;
				}
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	//un carré de couleur dont la taille peut varier en foction d'un paramètre (le besoin, l'argent, etc ?)
	aspect base {
		draw square(10) color:#blue;
	}
}

//Dans un premier temps, chaque intermédiaire est spécialisé dans un seul type, sauf les consommateurs qui auront les deux types (commun et supérieurs)
species Intermediaire {
	//un disque dont la taille varie en fonction du stock
	int stock <- 0;
	int capacite <- rnd(capaciteInter); //capacite d'achat auprès des producteurs
	int prix <- 0; //représente la pénalité ajoutée par l'intermédiaire.
	bool est_producteur; //représente la partie commerciale d'un producteur
	bool est_consommateur; //représente la partie commeriale d'un consommateur
	int argent;
	
	aspect base {
		if(not(est_producteur) and not(est_consommateur)){
			if (stock>0){
				draw circle(stock) color:#green;
			} else {
				draw circle(1) color:#green;
			}	
		}
	}
}

species Producteur{
	int production <- prodTauxFixe + rnd(prodTaux) update:prodTauxFixe + rnd(prodTaux) ;//représente le nombre de marchandise produite en 1 cycle
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe + rnd(stock_max_prod);
	Intermediaire mon_inter;
	
	reflex produit when: stock/*+production*/<stockMax{
		stock <- stock+production;
	}
	
	reflex updateInter{
		mon_inter.stock<-stock;
	}
	
	reflex vendre { //on vend à tous les intermédiaires qui ne sont pas des producteurs
		if(mon_inter.stock>0){
//			do vente0;
			do vente1;
//			do vente2;
		}
	}
	
	action vente0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediaire where not(each.est_producteur)){
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite-stock,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
							if(self.est_consommateur){
								write "vente conso " + self + " " + echange;
							} else {
								write "vente inter " + self + " " + echange;
							}
						}
					}
				}
			}
			mon_inter.stock <- stock;
	}
	
	action vente1{ //vente du maximum (en qantité) au plus proche
		list<Intermediaire> temp <- (Intermediaire where not(each.est_producteur));
		temp <- temp sort_by(each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite-stock,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
							if(self.est_consommateur){
								write "vente conso " + self + " " + echange;
							} else {
								write "vente inter " + self + " " + echange;
							}
						}
					}
				}
			}
			mon_inter.stock <- stock;
	}
	
	action vente2{ //Vente au plus loin
		list<Intermediaire> temp <- (Intermediaire where not(each.est_producteur));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite-stock,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
							if(self.est_consommateur){
								write "vente conso " + self + " " + echange;
							} else {
								write "vente inter " + self + " " + echange;
							}
						}
					}
				}
			}
			mon_inter.stock <- stock;
	}
	
	//un triangle dont la taille va dépenre du stock
	aspect base {
		if (stock>0){
			draw triangle(stock) color:#red;
		}else {
			draw triangle(1) color:#red;
		}
	}
}

//TODO : créer des entitées marchandises qui seront réellements échangées entre les intermédiaires. Cela permettrait aussi le traçage des marchandises (pour la sortie)
species Marchandise{
	int type;
	int quantity;
	Intermediaire provenance; //le dernier inter avant achat
	Producteur lieuProd; //l'endroit où la marchandise a été produite
	
	//un carré de taille fixe, la couleur pourrait varier en fonction du type de marchandise.
	aspect base {
		
	}
}

experiment Propagation type: gui {

	
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