import { LightningElement, wire, track } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import API_SELECTED_CHANNEL from '@salesforce/messageChannel/ApiSelected__c';
import API_STUDIO_EVENTS from '@salesforce/messageChannel/ApiStudioEvents__c';
import { publish } from 'lightning/messageService';
import getSidebarItems from '@salesforce/apex/OpenApiManagerController.getSidebarItems';
import deployAutoSyncConfigs from '@salesforce/apex/OpenApiManagerController.deployAutoSyncConfigs';
import checkDeploymentStatus from '@salesforce/apex/OpenApiManagerController.checkDeploymentStatus';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const POLL_INTERVAL_MS = 2000;
const SUCCESS_DEPLOYMENT_STATUSES = ['Succeeded', 'SucceededPartial'];
const TERMINAL_DEPLOYMENT_STATUSES = [...SUCCESS_DEPLOYMENT_STATUSES, 'Failed', 'Aborted', 'Canceled'];

export default class ApiSidebar extends LightningElement {
    @track items = [];
    @track filteredItems = [];
    @track searchTerm = '';
    @track onlyNew = false;
    @track selectedClass = '';
    @track isDeployingAutoSync = false;

    wiredItemsResult;
    subscription = null;
    pollTimeoutId;

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

    async handleDeployAutoSync() {
        if (this.isDeployingAutoSync) return;
        this.isDeployingAutoSync = true;
        try {
            const jobId = await deployAutoSyncConfigs();
            this.showToast('Deploying', 'Auto-sync deployment started. Monitoring status...', 'info');
            this.pollAutoSyncDeployment(jobId);
        } catch (e) {
            this.isDeployingAutoSync = false;
            this.showToast('Error', this.getErrorMessage(e), 'error');
        }
    }

    pollAutoSyncDeployment(jobId) {
        if (this.pollTimeoutId) clearTimeout(this.pollTimeoutId);

        const checkStatus = async () => {
            try {
                const status = await checkDeploymentStatus({ jobId });
                if (TERMINAL_DEPLOYMENT_STATUSES.includes(status)) {
                    this.isDeployingAutoSync = false;
                    if (SUCCESS_DEPLOYMENT_STATUSES.includes(status)) {
                        this.showToast('Success', 'Auto-sync deployment completed.', 'success');
                        refreshApex(this.wiredItemsResult);
                        publish(this.messageContext, API_STUDIO_EVENTS, { action: 'refreshSidebar' });
                    } else {
                        this.showToast('Error', 'Deployment ' + status, 'error');
                    }
                    return;
                }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.pollTimeoutId = setTimeout(checkStatus, POLL_INTERVAL_MS);
            } catch (e) {
                this.isDeployingAutoSync = false;
                this.showToast('Error', this.getErrorMessage(e), 'error');
            }
        };

        checkStatus();
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}