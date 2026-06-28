/**
 * @description Advanced API for testing complex path and parameter scenarios.
 */
@RestResource(urlMapping='/v1/complex/*')
global with sharing class ComplexApi {

    /**
     * @description A very complex endpoint with path override and multi-line param.
     * @path /nested/{parentId}/items/{childId}
     * @param {String} parentId [path] The ID of the parent account.
     * @param {String} childId [path] The ID of the specific item.
     * @param {
     *   filter: string,
     *   limit: integer
     * } options [query] Search and pagination options.
     * @response 200 {Account} Successful nested fetch.
     */
    @HttpGet
    global static Account getComplexData() {
        return new Account(Name = 'Complex Mock');
    }
}
