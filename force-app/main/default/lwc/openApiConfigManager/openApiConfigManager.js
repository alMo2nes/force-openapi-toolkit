import { LightningElement, wire, track } from 'lwc';
import { subscribe, publish, MessageContext } from 'lightning/messageService';
import API_SELECTED_CHANNEL from '@salesforce/messageChannel/ApiSelected__c';
import API_STUDIO_EVENTS from '@salesforce/messageChannel/ApiStudioEvents__c';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import CODEMIRROR from '@salesforce/resourceUrl/codemirror';
import getConfigsForClass from '@salesforce/apex/OpenApiManagerController.getConfigsForClass';
import saveConfigs from '@salesforce/apex/OpenApiManagerController.saveConfigs';
import checkDeploymentStatus from '@salesforce/apex/OpenApiManagerController.checkDeploymentStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const OPENAPI_KEYWORDS = ["openapi", "info", "title", "description", "version", "servers", "url", "paths", "get", "post", "put", "patch", "delete", "parameters", "name", "in", "required", "schema", "type", "format", "responses", "content", "application/json", "properties", "items", "operationId", "summary", "tags", "requestBody", "deprecated"];
const THEMES = [{ label: 'Dracula', value: 'dracula' }, { label: 'Material', value: 'material' }, { label: 'Monokai', value: 'monokai' }, { label: 'Default', value: 'default' }];
const SUCCESS_DEPLOYMENT_STATUSES = ['Succeeded', 'SucceededPartial'];
const TERMINAL_DEPLOYMENT_STATUSES = [...SUCCESS_DEPLOYMENT_STATUSES, 'Failed', 'Aborted', 'Canceled'];
const POLL_INTERVAL_MS = 2000;
const EDITOR_REFRESH_DELAY_MS = 150;
const POST_DEPLOY_RELOAD_DELAY_MS = 1500;
const EMPTY_RELOAD_RETRY_DELAY_MS = 1000;
const MAX_EMPTY_RELOAD_RETRIES = 3;

export default class OpenApiConfigManager extends LightningElement {
    @track selectedClass = '';
    @track comparisons = null;
    @track selectedTheme = 'dracula';
    @track activeSections = [];
    isSaving = false;
    codeMirrorLoaded = false;
    codeMirrorLoadingPromise;
    editors = new Map();
    subscription = null;
    themeOptions = THEMES;
    pollTimeoutId;
    loadSequence = 0;
    editorsInitialized = false;

    @wire(MessageContext) messageContext;

    get cardTitle() { return this.selectedClass ? `Managing: ${this.selectedClass}` : 'API Endpoint Manager'; }

    connectedCallback() {
        this.loadCodeMirror();
        this.subscribeToMessageChannel();
    }

    renderedCallback() {
        this.initEditors();
    }

    disconnectedCallback() {
        this.clearPollTimeout();
        this.destroyEditors();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(this.messageContext, API_SELECTED_CHANNEL, (m) => {
                this.selectedClass = m.className;
                this.loadConfigurations();
            });
        }
    }

    loadCodeMirror() {
        if (this.codeMirrorLoaded) return Promise.resolve();
        if (this.codeMirrorLoadingPromise) return this.codeMirrorLoadingPromise;

        const base = CODEMIRROR;
        this.codeMirrorLoadingPromise = Promise.all([
            loadStyle(this, base + '/lib/codemirror.css'), loadStyle(this, base + '/addon/lint/lint.css'),
            loadStyle(this, base + '/addon/hint/show-hint.css'), loadStyle(this, base + '/addon/fold/foldgutter.css'),
            loadStyle(this, base + '/theme/dracula.css'), loadStyle(this, base + '/theme/material.css'),
            loadStyle(this, base + '/theme/monokai.css'),
            loadScript(this, base + '/lib/codemirror.js'), loadScript(this, base + '/jsonlint.js')
        ]).then(() => {
            return Promise.all([
                loadScript(this, base + '/mode/javascript/javascript.js'), loadScript(this, base + '/addon/lint/lint.js'),
                loadScript(this, base + '/addon/edit/matchbrackets.js'), loadScript(this, base + '/addon/edit/closebrackets.js'),
                loadScript(this, base + '/addon/hint/show-hint.js'), loadScript(this, base + '/addon/fold/foldcode.js'),
                loadScript(this, base + '/addon/fold/foldgutter.js'), loadScript(this, base + '/addon/fold/brace-fold.js'),
                loadScript(this, base + '/addon/hint/javascript-hint.js'), loadScript(this, base + '/addon/lint/json-lint.js')
            ]);
        }).then(() => {
            this.registerOpenApiHinter();
            this.codeMirrorLoaded = true;
            this.initEditors();
        }).catch((e) => {
            this.showToast('Error', this.getErrorMessage(e), 'error');
        }).finally(() => {
            this.codeMirrorLoadingPromise = null;
        });

        return this.codeMirrorLoadingPromise;
    }

    registerOpenApiHinter() {
        if (!window.CodeMirror) return;
        window.CodeMirror.registerHelper("hint", "openapi", (editor) => {
            const cur = editor.getCursor(); const token = editor.getTokenAt(cur);
            let search = '';
            if (token.type === "string" || token.string.startsWith('"') || /^[a-zA-Z0-9_]+$/.test(token.string)) {
                search = token.string.replace(/"/g, '');
            }
            const list = OPENAPI_KEYWORDS.filter(w => w.toLowerCase().startsWith(search.toLowerCase()))
                .map(w => ({ text: '"' + w + '": ', displayText: w }));
            return { list, from: window.CodeMirror.Pos(cur.line, token.start), to: window.CodeMirror.Pos(cur.line, token.end) };
        });
    }

    async loadConfigurations(options = {}) {
        if (!this.selectedClass) return;
        const { retryWhenEmpty = false, emptyRetryCount = 0 } = options;
        const requestSequence = ++this.loadSequence;
        
        this.comparisons = null;
        this.activeSections = [];
        this.editorsInitialized = false;
        this.destroyEditors();

        try {
            const data = await getConfigsForClass({ className: this.selectedClass });
            if (requestSequence !== this.loadSequence) return;

            if (retryWhenEmpty && data.length === 0 && emptyRetryCount < MAX_EMPTY_RELOAD_RETRIES) {
                await this.wait(EMPTY_RELOAD_RETRY_DELAY_MS);
                if (requestSequence === this.loadSequence) {
                    this.loadConfigurations({ retryWhenEmpty: true, emptyRetryCount: emptyRetryCount + 1 });
                }
                return;
            }

            this.comparisons = data.map(c => ({ 
                ...c, 
                pathMatches: c.currentPath === c.srcPath, 
                specMatches: c.currentSpec === c.srcSpec, 
                accordionLabel: `${c.httpMethod} ${c.methodName}` 
            }));
            
            if (this.comparisons.length > 0 && this.activeSections.length === 0) {
                this.activeSections = [this.comparisons[0].methodName];
            }
        } catch (e) { 
            this.showToast('Error', this.getErrorMessage(e), 'error'); 
        }
    }

    initEditors() {
        if (!this.codeMirrorLoaded || !this.comparisons || this.editorsInitialized) return;

        this.comparisons.forEach(comp => {
            const workingHost = this.template.querySelector(`.working-editor[data-key="${comp.methodName}"]`);
            const sourceHost = this.template.querySelector(`.source-editor[data-key="${comp.methodName}"]`);

            if (!workingHost || !sourceHost) return;

            workingHost.replaceChildren();
            sourceHost.replaceChildren();

            const config = { mode: { name: "javascript", json: true }, lineNumbers: true, lineWrapping: true, matchBrackets: true, autoCloseBrackets: true, foldGutter: true, gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter", "CodeMirror-lint-markers"], lint: true, smartIndent: true, indentUnit: 2, theme: this.selectedTheme };
            
            const ed = window.CodeMirror(workingHost, config);
            ed.setValue(comp.currentSpec || ''); ed.setSize(null, 500);
            ed.on('change', (cm) => this.updateComparisonField(comp.methodName, 'currentSpec', cm.getValue()));
            this.editors.set(comp.methodName + '_working', ed);

            const srcEd = window.CodeMirror(sourceHost, { ...config, readOnly: true });
            srcEd.setValue(comp.srcSpec || ''); srcEd.setSize(null, 500);
            this.editors.set(comp.methodName + '_source', srcEd);
        });

        this.editorsInitialized = this.comparisons.length === 0 || this.comparisons.every(comp => this.editors.has(comp.methodName + '_working') && this.editors.has(comp.methodName + '_source'));
        if (this.editorsInitialized) {
            this.scheduleEditorRefresh();
        }
    }

    async handleSave() {
        if (this.isSaving || !this.comparisons || this.comparisons.length === 0) return;

        const validationError = this.getFirstJsonValidationError();
        if (validationError) {
            this.showToast('Invalid JSON', validationError, 'error');
            return;
        }

        this.isSaving = true;
        try {
            const configs = this.comparisons.map(comp => JSON.stringify(comp));
            const jobId = await saveConfigs({ jsonConfigs: configs });
            this.showToast('Deploying', 'Deployment started. Monitoring status...', 'info');
            this.pollDeployment(jobId);
        } catch (e) { 
            this.showToast('Error', this.getErrorMessage(e), 'error'); 
            this.isSaving = false; 
        }
    }

    pollDeployment(jobId) {
        this.clearPollTimeout();

        const checkStatus = async () => {
            try {
                const status = await checkDeploymentStatus({ jobId });
                if (TERMINAL_DEPLOYMENT_STATUSES.includes(status)) {
                    if (SUCCESS_DEPLOYMENT_STATUSES.includes(status)) {
                        this.showToast('Success', 'Metadata deployment completed.', 'success');
                        this.isSaving = false;
                        publish(this.messageContext, API_STUDIO_EVENTS, { action: 'refreshSidebar' });
                        await this.wait(POST_DEPLOY_RELOAD_DELAY_MS);
                        this.loadConfigurations({ retryWhenEmpty: true });
                    } else {
                        this.isSaving = false;
                        this.showToast('Error', 'Deployment ' + status, 'error');
                    }
                    return;
                }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.pollTimeoutId = setTimeout(checkStatus, POLL_INTERVAL_MS);
            } catch(e) {
                this.isSaving = false;
                this.showToast('Error', this.getErrorMessage(e), 'error');
            }
        };

        checkStatus();
    }

    handleReload() { this.loadConfigurations(); }
    handleThemeChange(event) {
        this.selectedTheme = event.detail.value;
        this.editors.forEach(editor => editor.setOption('theme', this.selectedTheme));
        this.scheduleEditorRefresh();
    }
    handleSectionToggle() { this.scheduleEditorRefresh(); }
    handleSyncPath(event) { const comp = this.getComparison(event.target.dataset.key); if (comp) this.updateComparisonField(comp.methodName, 'currentPath', comp.srcPath); }
    handleSyncSpec(event) { const key = event.target.dataset.key; const comp = this.getComparison(key); const ed = this.editors.get(key + '_working'); if (comp && ed) { ed.setValue(comp.srcSpec); this.updateComparisonField(key, 'currentSpec', comp.srcSpec); } }
    handleValidate(event) { const ed = this.editors.get(event.target.dataset.key + '_working'); try { JSON.parse(ed ? ed.getValue() : ''); this.showToast('Valid', 'JSON is correct.', 'success'); } catch (e) { this.showToast('Invalid JSON', e.message, 'error'); } }
    handleInputChange(event) { this.updateComparisonField(event.target.dataset.key, event.target.dataset.field, event.target.value); }
    handleToggleActive(event) { this.updateComparisonField(event.target.dataset.key, 'currentActive', event.target.checked); }
    handleToggleDeprecated(event) { this.updateComparisonField(event.target.dataset.key, 'currentDeprecated', event.target.checked); }

    updateComparisonField(key, field, value) {
        this.comparisons = this.comparisons.map(comp => {
            if (comp.methodName === key) {
                const updated = { ...comp, [field]: value };
                updated.pathMatches = updated.currentPath === updated.srcPath;
                updated.specMatches = updated.currentSpec === updated.srcSpec;
                return updated;
            }
            return comp;
        });
    }

    getComparison(key) {
        return this.comparisons?.find(c => c.methodName === key);
    }

    getFirstJsonValidationError() {
        for (const comp of this.comparisons) {
            try {
                JSON.parse(comp.currentSpec || '');
            } catch (e) {
                return `${comp.httpMethod} ${comp.methodName}: ${e.message}`;
            }
        }
        return null;
    }

    destroyEditors() {
        this.editors.forEach(editor => {
            const wrapper = editor.getWrapperElement?.();
            if (wrapper?.parentNode) {
                wrapper.parentNode.removeChild(wrapper);
            }
        });
        this.editors.clear();
    }

    clearPollTimeout() {
        if (this.pollTimeoutId) {
            clearTimeout(this.pollTimeoutId);
            this.pollTimeoutId = undefined;
        }
    }

    scheduleEditorRefresh() {
        this.refreshEditors();
        // CodeMirror needs a second refresh after lightning-accordion finishes opening sections.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.refreshEditors(), EDITOR_REFRESH_DELAY_MS);
    }

    refreshEditors() {
        this.editors.forEach(editor => editor.refresh());
    }

    wait(milliseconds) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        return new Promise(resolve => setTimeout(resolve, milliseconds));
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }

    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}