import { LightningElement, wire, track } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import API_SELECTED_CHANNEL from '@salesforce/messageChannel/ApiSelected__c';
import API_STUDIO_EVENTS from '@salesforce/messageChannel/ApiStudioEvents__c';
import { publish } from 'lightning/messageService';
import getSidebarItems from '@salesforce/apex/OpenApiManagerController.getSidebarItems';
import { refreshApex } from '@salesforce/apex';

export default class ApiSidebar extends LightningElement {
    @track items = [];
    @track filteredItems = [];
    @track searchTerm = '';
    @track onlyNew = false;
    @track selectedClass = '';
    
    wiredItemsResult;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    @wire(getSidebarItems)
    wiredItems(result) {
        this.wiredItemsResult = result;
        if (result.data) {
            this.items = result.data;
            this.applyFilters();
        }
    }

    connectedCallback() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                API_STUDIO_EVENTS,
                (message) => {
                    if (message.action === 'refreshSidebar') {
                        refreshApex(this.wiredItemsResult);
                    }
                }
            );
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleFilterToggle(event) {
        this.onlyNew = event.target.checked;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredItems = this.items
            .filter(item => {
                const matchesSearch = item.className.toLowerCase().includes(this.searchTerm);
                const matchesFilter = this.onlyNew ? !item.hasConfig : true;
                return matchesSearch && matchesFilter;
            })
            .map(item => ({
                ...item,
                classNameAttr: `item-row slds-p-around_small ${item.className === this.selectedClass ? 'is-selected' : ''}`
            }));
    }

    handleItemSelect(event) {
        this.selectedClass = event.currentTarget.dataset.name;
        this.applyFilters();
        publish(this.messageContext, API_SELECTED_CHANNEL, { className: this.selectedClass });
    }
}